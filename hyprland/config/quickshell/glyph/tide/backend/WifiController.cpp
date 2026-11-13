#include "WifiController.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusContext>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <QDBusPendingCall>
#include <QDBusReply>
#include <QDBusVariant>
#include <QMap>
#include <QMetaType>
#include <QVariant>
#include <QUuid>
#include <QElapsedTimer>
#include <QFutureWatcher>
#include <QtConcurrent/QtConcurrentRun>
#include <algorithm>
#include <utility>

using ConnectionSettingsMap = WifiController::ConnectionSettingsMap;
using ObjectPathList = QList<QDBusObjectPath>;
using IwdManagedObjectMap = QMap<QDBusObjectPath, ConnectionSettingsMap>;
using IwdOrderedNetworkList = QList<std::pair<QDBusObjectPath, qint16>>;
using IwdUserNameAndPassword = std::pair<QString, QString>;

Q_DECLARE_METATYPE(ConnectionSettingsMap)
Q_DECLARE_METATYPE(ObjectPathList)
Q_DECLARE_METATYPE(IwdManagedObjectMap)
Q_DECLARE_METATYPE(IwdOrderedNetworkList)
Q_DECLARE_METATYPE(IwdUserNameAndPassword)

// Only value data crosses the worker boundary. QML models, signals, timers and
// the passphrase agent remain on the controller's thread.
struct WifiRefreshSnapshot {
    QString backendName;
    QString devicePath;
    QString currentSsid;
    QString unsupportedReason;
    QString error;
    QHash<QString, QString> savedConnections;
    QVector<WifiNetworkModel::NetworkEntry> networks;
    bool supported = false;
    bool available = false;
    bool enabled = false;
    bool scanning = false;
    bool stateValid = false;
    bool networksValid = false;
    bool savedConnectionsRefreshed = false;
    bool scanAttempted = false;
};

namespace {

constexpr auto kDbusService = "org.freedesktop.DBus";
constexpr auto kDbusPath = "/org/freedesktop/DBus";
constexpr auto kDbusInterface = "org.freedesktop.DBus";
constexpr auto kDbusPropertiesInterface = "org.freedesktop.DBus.Properties";
constexpr auto kNetworkManagerService = "org.freedesktop.NetworkManager";
constexpr auto kNetworkManagerPath = "/org/freedesktop/NetworkManager";
constexpr auto kNetworkManagerInterface = "org.freedesktop.NetworkManager";
constexpr auto kNetworkManagerDeviceInterface = "org.freedesktop.NetworkManager.Device";
constexpr auto kNetworkManagerWirelessInterface = "org.freedesktop.NetworkManager.Device.Wireless";
constexpr auto kNetworkManagerAccessPointInterface = "org.freedesktop.NetworkManager.AccessPoint";
constexpr auto kNetworkManagerSettingsPath = "/org/freedesktop/NetworkManager/Settings";
constexpr auto kNetworkManagerSettingsInterface = "org.freedesktop.NetworkManager.Settings";
constexpr auto kNetworkManagerSettingsConnectionInterface = "org.freedesktop.NetworkManager.Settings.Connection";
constexpr auto kIwdService = "net.connman.iwd";
constexpr auto kIwdAgentManagerPath = "/net/connman/iwd";
constexpr auto kIwdAgentManagerInterface = "net.connman.iwd.AgentManager";
constexpr auto kIwdDeviceInterface = "net.connman.iwd.Device";
constexpr auto kIwdStationInterface = "net.connman.iwd.Station";
constexpr auto kIwdNetworkInterface = "net.connman.iwd.Network";
constexpr auto kIwdAgentObjectPath = "/com/tideisland/IslandBackend/IwdAgent";
constexpr auto kObjectManagerInterface = "org.freedesktop.DBus.ObjectManager";
constexpr auto kIwdAgentCanceledError = "net.connman.iwd.Agent.Error.Canceled";
constexpr auto kConnmanService = "net.connman";
constexpr auto kRootPath = "/";

constexpr uint kWifiDeviceType = 2;
constexpr uint kAccessPointPrivacyFlag = 0x1;

QDBusArgument &operator<<(QDBusArgument &argument, const ConnectionSettingsMap &settings) {
    argument.beginMap(QMetaType::fromType<QString>(), QMetaType::fromType<QVariantMap>());
    for (auto it = settings.cbegin(); it != settings.cend(); ++it) {
        argument.beginMapEntry();
        argument << it.key() << it.value();
        argument.endMapEntry();
    }
    argument.endMap();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, ConnectionSettingsMap &settings) {
    settings.clear();
    argument.beginMap();
    while (!argument.atEnd()) {
        QString key;
        QVariantMap value;
        argument.beginMapEntry();
        argument >> key >> value;
        argument.endMapEntry();
        settings.insert(key, value);
    }
    argument.endMap();
    return argument;
}

QVariant unwrapVariant(const QVariant &variant) {
    if (variant.metaType().id() == qMetaTypeId<QDBusVariant>())
        return qvariant_cast<QDBusVariant>(variant).variant();
    return variant;
}

QString decodeSsid(const QByteArray &ssidBytes) {
    if (ssidBytes.isEmpty())
        return {};

    const QString utf8 = QString::fromUtf8(ssidBytes);
    return utf8.contains(QChar::ReplacementCharacter) ? QString::fromLatin1(ssidBytes) : utf8;
}

QByteArray byteArrayFromVariant(const QVariant &variant) {
    const QVariant raw = unwrapVariant(variant);

    if (raw.metaType().id() == QMetaType::QByteArray)
        return raw.toByteArray();

    if (raw.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = qvariant_cast<QDBusArgument>(raw);
        return qdbus_cast<QByteArray>(argument);
    }

    if (raw.metaType().id() == QMetaType::QVariantList) {
        QByteArray bytes;
        const QVariantList values = raw.toList();
        bytes.reserve(values.size());
        for (const QVariant &value : values)
            bytes.append(static_cast<char>(value.toUInt()));
        return bytes;
    }

    return {};
}

ConnectionSettingsMap connectionSettingsFromVariant(const QVariant &variant) {
    const QVariant raw = unwrapVariant(variant);

    if (raw.metaType().id() == qMetaTypeId<ConnectionSettingsMap>())
        return qvariant_cast<ConnectionSettingsMap>(raw);

    if (raw.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = qvariant_cast<QDBusArgument>(raw);
        return qdbus_cast<ConnectionSettingsMap>(argument);
    }

    return {};
}

IwdManagedObjectMap managedObjectsFromVariant(const QVariant &variant) {
    const QVariant raw = unwrapVariant(variant);

    if (raw.metaType().id() == qMetaTypeId<IwdManagedObjectMap>())
        return qvariant_cast<IwdManagedObjectMap>(raw);

    if (raw.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = qvariant_cast<QDBusArgument>(raw);
        return qdbus_cast<IwdManagedObjectMap>(argument);
    }

    return {};
}

IwdOrderedNetworkList iwdOrderedNetworksFromVariant(const QVariant &variant) {
    const QVariant raw = unwrapVariant(variant);

    if (raw.metaType().id() == qMetaTypeId<IwdOrderedNetworkList>())
        return qvariant_cast<IwdOrderedNetworkList>(raw);

    if (raw.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = qvariant_cast<QDBusArgument>(raw);
        return qdbus_cast<IwdOrderedNetworkList>(argument);
    }

    return {};
}

ObjectPathList objectPathsFromVariant(const QVariant &variant) {
    const QVariant raw = unwrapVariant(variant);

    if (raw.metaType().id() == qMetaTypeId<ObjectPathList>())
        return qvariant_cast<ObjectPathList>(raw);

    if (raw.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = qvariant_cast<QDBusArgument>(raw);
        return qdbus_cast<ObjectPathList>(argument);
    }

    if (raw.metaType().id() == QMetaType::QStringList) {
        ObjectPathList paths;
        for (const QString &path : raw.toStringList())
            paths.append(QDBusObjectPath(path));
        return paths;
    }

    return {};
}

QString objectPathFromVariant(const QVariant &variant) {
    const QVariant raw = unwrapVariant(variant);

    if (raw.metaType().id() == qMetaTypeId<QDBusObjectPath>())
        return qvariant_cast<QDBusObjectPath>(raw).path();

    if (raw.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = qvariant_cast<QDBusArgument>(raw);
        return qdbus_cast<QDBusObjectPath>(argument).path();
    }

    return raw.toString();
}

QString labelForSsid(const QString &ssid) {
    const QString trimmed = ssid.trimmed();
    return trimmed.isEmpty() ? QStringLiteral("Hidden network") : trimmed;
}

bool isValidPath(const QString &path) {
    return !path.isEmpty() && path != QLatin1String(kRootPath);
}

int signalPercentFromIwd(qint16 signalStrength) {
    return std::clamp((static_cast<int>(signalStrength) + 10000) / 100, 0, 100);
}

bool isIwdSecureNetwork(const QString &networkType) {
    return networkType != QLatin1String("open");
}

QString titleCaseBackendName(const QString &backendName) {
    if (backendName == QLatin1String("iwd"))
        return QStringLiteral("iwd");
    if (backendName == QLatin1String("connman"))
        return QStringLiteral("ConnMan");
    if (backendName == QLatin1String("networkmanager"))
        return QStringLiteral("NetworkManager");
    return QStringLiteral("Wi-Fi");
}

struct WifiRefreshRequest {
    QString backendName;
    QHash<QString, QString> savedConnections;
    std::shared_ptr<std::atomic_bool> cancellation;
    bool reloadSavedConnections = false;
    bool rescan = false;
    bool scanning = false;
};

struct RefreshError { QString message; };
struct RefreshDeadline {};
struct RefreshCanceled {};

class WifiSnapshotReader {
public:
    explicit WifiSnapshotReader(WifiRefreshRequest request)
        : m_request(std::move(request)) {
        m_elapsed.start();
        m_result.backendName = m_request.backendName;
        m_result.savedConnections = m_request.savedConnections;
        m_result.scanning = m_request.scanning;
    }

    WifiRefreshSnapshot read() {
        try {
            detectBackend();
            if (m_result.backendName == QLatin1String("networkmanager"))
                readNetworkManager();
            else if (m_result.backendName == QLatin1String("iwd"))
                readIwd();
        } catch (const RefreshError &error) {
            m_result.error = error.message;
        } catch (const RefreshDeadline &) {
            m_result.error = QStringLiteral("Wi-Fi refresh timed out.");
        } catch (const RefreshCanceled &) {
            // The owner discards this generation; stop before another call.
        }
        return m_result;
    }

private:
    QDBusMessage call(const QString &service, const QString &path,
                      const QString &interface, const QString &method,
                      const QList<QVariant> &arguments = {}) {
        if (m_request.cancellation->load())
            throw RefreshCanceled {};
        // Bound both a single unresponsive service and the whole snapshot.
        const int remaining = 12000 - int(m_elapsed.elapsed());
        if (remaining <= 0)
            throw RefreshDeadline {};
        auto message = QDBusMessage::createMethodCall(service, path, interface, method);
        message.setArguments(arguments);
        message.setAutoStartService(false);
        const auto reply = QDBusConnection::systemBus().call(message, QDBus::Block, std::min(1500, remaining));
        if (m_request.cancellation->load())
            throw RefreshCanceled {};
        return reply;
    }

    QDBusMessage checkedCall(const QString &service, const QString &path,
                             const QString &interface, const QString &method,
                             const QList<QVariant> &arguments = {}) {
        const auto reply = call(service, path, interface, method, arguments);
        if (reply.errorName().endsWith(QLatin1String(".NoReply"))
            || reply.errorName().endsWith(QLatin1String(".Timeout"))
            || reply.errorName().endsWith(QLatin1String(".TimedOut")))
            throw RefreshDeadline {};
        if (reply.type() == QDBusMessage::ErrorMessage)
            throw RefreshError {reply.errorMessage().isEmpty() ? reply.errorName() : reply.errorMessage()};
        return reply;
    }

    QVariantMap properties(const QString &service, const QString &path, const QString &interface) {
        const auto reply = checkedCall(service, path, kDbusPropertiesInterface,
                                       QStringLiteral("GetAll"), {interface});
        return qdbus_cast<QVariantMap>(reply.arguments().value(0));
    }

    bool hasService(const QString &service) {
        return checkedCall(kDbusService, kDbusPath, kDbusInterface,
                           QStringLiteral("NameHasOwner"), {service}).arguments().value(0).toBool();
    }

    void detectBackend() {
        if (hasService(kNetworkManagerService)) {
            m_result.backendName = QStringLiteral("networkmanager");
        } else if (hasService(kIwdService)) {
            m_result.backendName = QStringLiteral("iwd");
        } else {
            const bool connman = hasService(kConnmanService);
            m_result.backendName = connman ? QStringLiteral("connman") : QStringLiteral("unsupported");
            m_result.available = connman;
            m_result.unsupportedReason = connman
                ? QStringLiteral("Detected ConnMan, but this panel currently only supports NetworkManager.")
                : QStringLiteral("No supported Wi-Fi backend was detected.");
            m_result.stateValid = true;
            m_result.networksValid = true;
            m_result.scanning = false;
        }
    }

    bool deviceReady() {
        m_result.supported = true;
        m_result.available = isValidPath(m_result.devicePath);
        if (m_result.available && m_result.enabled)
            return true;
        m_result.stateValid = true;
        m_result.scanning = false;
        m_result.networksValid = true;
        return false;
    }

    void scan(const QString &service, const QString &interface, const QString &method,
              const QList<QVariant> &arguments = {}) {
        if (!m_request.rescan)
            return;
        if (m_request.cancellation->load())
            throw RefreshCanceled {};
        m_result.scanAttempted = true;
        const auto reply = call(service, m_result.devicePath, interface, method, arguments);
        const bool busy = service == QLatin1String(kIwdService)
            && reply.errorName().endsWith(QLatin1String(".Busy"));
        m_result.scanning = reply.type() != QDBusMessage::ErrorMessage || busy;
        if (!m_result.scanning)
            m_result.error = reply.errorMessage();
    }

    void readSavedConnections() {
        if (!m_request.reloadSavedConnections && m_request.backendName == m_result.backendName)
            return;
        const auto reply = checkedCall(kNetworkManagerService, kNetworkManagerSettingsPath,
                                       kNetworkManagerSettingsInterface, QStringLiteral("ListConnections"));
        QHash<QString, QString> saved;
        for (const auto &path : objectPathsFromVariant(reply.arguments().value(0))) {
            const auto settingsReply = checkedCall(kNetworkManagerService, path.path(),
                kNetworkManagerSettingsConnectionInterface, QStringLiteral("GetSettings"));
            const auto settings = connectionSettingsFromVariant(settingsReply.arguments().value(0));
            const auto connection = settings.value(QStringLiteral("connection"));
            if (connection.value(QStringLiteral("type")).toString() != QLatin1String("802-11-wireless"))
                continue;
            auto ssid = decodeSsid(byteArrayFromVariant(settings.value(QStringLiteral("802-11-wireless"))
                                                        .value(QStringLiteral("ssid"))));
            if (ssid.isEmpty())
                ssid = connection.value(QStringLiteral("id")).toString().trimmed();
            if (!ssid.isEmpty())
                saved.insert(ssid, path.path());
        }
        m_result.savedConnections = saved;
        m_result.savedConnectionsRefreshed = true;
    }

    void readNetworkManager() {
        const auto manager = properties(kNetworkManagerService, kNetworkManagerPath, kNetworkManagerInterface);
        m_result.enabled = manager.value(QStringLiteral("WirelessEnabled")).toBool();
        for (const auto &path : objectPathsFromVariant(manager.value(QStringLiteral("Devices")))) {
            const auto device = properties(kNetworkManagerService, path.path(), kNetworkManagerDeviceInterface);
            if (device.value(QStringLiteral("DeviceType")).toUInt() == kWifiDeviceType) {
                m_result.devicePath = path.path();
                break;
            }
        }
        if (!deviceReady())
            return;

        const auto wireless = properties(kNetworkManagerService, m_result.devicePath, kNetworkManagerWirelessInterface);
        const auto activePath = objectPathFromVariant(wireless.value(QStringLiteral("ActiveAccessPoint")));
        QHash<QString, QVariantMap> accessPointProperties;
        if (isValidPath(activePath)) {
            try {
                const auto active = properties(kNetworkManagerService, activePath, kNetworkManagerAccessPointInterface);
                accessPointProperties.insert(activePath, active);
                m_result.currentSsid = decodeSsid(byteArrayFromVariant(active.value(QStringLiteral("Ssid"))));
            } catch (const RefreshError &) {
                // An AP can disappear between the device and AP snapshots.
            }
        }
        m_result.stateValid = true;
        try {
            readSavedConnections();
        } catch (const RefreshError &) {
            // Keep the last known saved connections and retry next refresh.
        }
        scan(kNetworkManagerService, kNetworkManagerWirelessInterface, QStringLiteral("RequestScan"),
             {QVariant::fromValue(QVariantMap {})});
        const auto reply = checkedCall(kNetworkManagerService, m_result.devicePath,
                                       kNetworkManagerWirelessInterface, QStringLiteral("GetAllAccessPoints"));
        QMap<QString, WifiNetworkModel::NetworkEntry> networksByKey;
        for (const auto &path : objectPathsFromVariant(reply.arguments().value(0))) {
            QVariantMap ap;
            try {
                ap = accessPointProperties.contains(path.path()) ? accessPointProperties.value(path.path())
                    : properties(kNetworkManagerService, path.path(), kNetworkManagerAccessPointInterface);
            } catch (const RefreshError &) {
                continue;
            }
            WifiNetworkModel::NetworkEntry entry;
            entry.objectPath = path.path();
            entry.ssid = decodeSsid(byteArrayFromVariant(ap.value(QStringLiteral("Ssid"))));
            entry.displayName = labelForSsid(entry.ssid);
            entry.signal = ap.value(QStringLiteral("Strength")).toInt();
            entry.secure = (ap.value(QStringLiteral("Flags")).toUInt() & kAccessPointPrivacyFlag) != 0
                || ap.value(QStringLiteral("WpaFlags")).toUInt() != 0 || ap.value(QStringLiteral("RsnFlags")).toUInt() != 0;
            entry.type = entry.secure ? QStringLiteral("secure") : QStringLiteral("open");
            entry.savedConnection = m_result.savedConnections.contains(entry.ssid);
            entry.connected = !m_result.currentSsid.isEmpty() && entry.ssid == m_result.currentSsid;
            const auto key = entry.ssid.isEmpty() ? QStringLiteral("__hidden__") : entry.ssid;
            const auto existing = networksByKey.constFind(key);
            if (existing == networksByKey.cend() || (entry.connected && !existing->connected)
                || (entry.connected == existing->connected && entry.signal > existing->signal))
                networksByKey.insert(key, entry);
        }
        m_result.networks = networksByKey.values().toVector();
        std::sort(m_result.networks.begin(), m_result.networks.end(), [](const auto &left, const auto &right) {
            if (left.connected != right.connected) return left.connected;
            if (left.signal != right.signal) return left.signal > right.signal;
            return QString::localeAwareCompare(left.displayName, right.displayName) < 0;
        });
        m_result.networksValid = true;
    }

    void readIwd() {
        const auto reply = checkedCall(kIwdService, kRootPath, kObjectManagerInterface,
                                       QStringLiteral("GetManagedObjects"));
        const auto objects = managedObjectsFromVariant(reply.arguments().value(0));
        QVariantMap station;
        int bestScore = -1;
        for (auto it = objects.cbegin(); it != objects.cend(); ++it) {
            if (!it->contains(QString::fromLatin1(kIwdDeviceInterface))
                || !it->contains(QString::fromLatin1(kIwdStationInterface))) continue;
            const auto device = it->value(QString::fromLatin1(kIwdDeviceInterface));
            const auto candidate = it->value(QString::fromLatin1(kIwdStationInterface));
            const auto state = candidate.value(QStringLiteral("State")).toString();
            const bool powered = device.value(QStringLiteral("Powered")).toBool();
            const int score = (state == QLatin1String("connected") || state == QLatin1String("connecting")
                               || state == QLatin1String("roaming") ? 4 : 0) + (powered ? 2 : 0);
            if (score <= bestScore) continue;
            bestScore = score;
            m_result.devicePath = it.key().path();
            m_result.enabled = powered;
            station = candidate;
        }
        if (!deviceReady())
            return;
        m_result.scanning = station.value(QStringLiteral("Scanning")).toBool();
        const auto connectedPath = objectPathFromVariant(station.value(QStringLiteral("ConnectedNetwork")));
        if (isValidPath(connectedPath)) {
            auto network = objects.value(QDBusObjectPath(connectedPath)).value(QString::fromLatin1(kIwdNetworkInterface));
            if (network.value(QStringLiteral("Name")).toString().isEmpty())
                network = properties(kIwdService, connectedPath, kIwdNetworkInterface);
            m_result.currentSsid = network.value(QStringLiteral("Name")).toString().trimmed();
        }
        m_result.stateValid = true;
        scan(kIwdService, kIwdStationInterface, QStringLiteral("Scan"));
        const auto orderedReply = checkedCall(kIwdService, m_result.devicePath, kIwdStationInterface,
                                              QStringLiteral("GetOrderedNetworks"));
        const auto orderedNetworks = iwdOrderedNetworksFromVariant(orderedReply.arguments().value(0));
        m_result.networks.reserve(orderedNetworks.size());
        for (const auto &record : orderedNetworks) {
            auto network = objects.value(record.first).value(QString::fromLatin1(kIwdNetworkInterface));
            if (network.value(QStringLiteral("Name")).toString().isEmpty()
                || network.value(QStringLiteral("Type")).toString().isEmpty()
                || !network.contains(QStringLiteral("Connected"))
                || !network.contains(QStringLiteral("KnownNetwork"))) {
                try {
                    network = properties(kIwdService, record.first.path(), kIwdNetworkInterface);
                } catch (const RefreshError &) {
                    continue;
                }
            }
            WifiNetworkModel::NetworkEntry entry;
            entry.objectPath = record.first.path();
            entry.ssid = network.value(QStringLiteral("Name")).toString().trimmed();
            entry.displayName = labelForSsid(entry.ssid);
            entry.type = network.value(QStringLiteral("Type")).toString().trimmed();
            entry.signal = signalPercentFromIwd(record.second);
            entry.secure = isIwdSecureNetwork(entry.type);
            entry.connected = network.value(QStringLiteral("Connected")).toBool();
            entry.savedConnection = isValidPath(objectPathFromVariant(network.value(QStringLiteral("KnownNetwork"))));
            m_result.networks.append(entry);
        }
        m_result.networksValid = true;
    }

    WifiRefreshRequest m_request;
    WifiRefreshSnapshot m_result;
    QElapsedTimer m_elapsed;
};

} // namespace

class IwdAgent final : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "net.connman.iwd.Agent")

public:
    explicit IwdAgent(WifiController *controller)
        : QObject(controller)
        , m_controller(controller) {
    }

public slots:
    void Release() {
        if (!m_controller)
            return;

        m_controller->setIwdAgentRegisteredState(false);
        m_controller->setIwdAgentRegistrationError({});
    }

    QString RequestPassphrase(const QDBusObjectPath &network) {
        return takePasswordOrReplyWithError(network.path());
    }

    QString RequestPrivateKeyPassphrase(const QDBusObjectPath &) {
        sendErrorReply(
            QString::fromLatin1(kIwdAgentCanceledError),
            QStringLiteral("Private key passphrases are not supported in this panel.")
        );
        return {};
    }

    IwdUserNameAndPassword RequestUserNameAndPassword(const QDBusObjectPath &) {
        sendErrorReply(
            QString::fromLatin1(kIwdAgentCanceledError),
            QStringLiteral("Enterprise Wi-Fi networks that need a user name must be provisioned first.")
        );
        return {};
    }

    QString RequestUserPassword(const QDBusObjectPath &network, const QString &) {
        return takePasswordOrReplyWithError(network.path());
    }

    void Cancel(const QString &) {
    }

private:
    QString takePasswordOrReplyWithError(const QString &networkPath) {
        if (!m_controller) {
            sendErrorReply(
                QString::fromLatin1(kIwdAgentCanceledError),
                QStringLiteral("The iwd agent is unavailable.")
            );
            return {};
        }

        const QString password = m_controller->takeIwdPassphraseForNetwork(networkPath);
        if (!password.isEmpty())
            return password;

        sendErrorReply(
            QString::fromLatin1(kIwdAgentCanceledError),
            QStringLiteral("No Wi-Fi passphrase is available for this network.")
        );
        return {};
    }

    WifiController *m_controller = nullptr;
};

WifiController::WifiController(QObject *parent)
    : QObject(parent) {
    qDebug() << "[Wifi] WifiController constructor called";
    qDBusRegisterMetaType<ObjectPathList>();
    qDBusRegisterMetaType<ConnectionSettingsMap>();
    qDBusRegisterMetaType<IwdManagedObjectMap>();
    qDBusRegisterMetaType<std::pair<QDBusObjectPath, qint16>>();
    qDBusRegisterMetaType<IwdOrderedNetworkList>();
    qDBusRegisterMetaType<IwdUserNameAndPassword>();
    qRegisterMetaType<ConnectionSettingsMap>("ConnectionSettingsMap");
    qRegisterMetaType<IwdManagedObjectMap>("IwdManagedObjectMap");
    qRegisterMetaType<IwdOrderedNetworkList>("IwdOrderedNetworkList");
    qRegisterMetaType<IwdUserNameAndPassword>("IwdUserNameAndPassword");

    m_stateRefreshTimer.setSingleShot(true);
    m_stateRefreshTimer.setInterval(80);
    connect(&m_stateRefreshTimer, &QTimer::timeout, this, &WifiController::refreshStateInternal);

    m_networkRefreshTimer.setSingleShot(true);
    m_networkRefreshTimer.setInterval(120);
    connect(&m_networkRefreshTimer, &QTimer::timeout, this, [this]() {
        refreshNetworksInternal(false, true);
    });

    m_scanTimeoutTimer.setSingleShot(true);
    m_scanTimeoutTimer.setInterval(5000);
    connect(&m_scanTimeoutTimer, &QTimer::timeout, this, [this]() {
        setScanningState(false);
        refreshNetworksInternal(false, true);
    });

    QDBusConnection::systemBus().connect(
        kDbusService,
        kDbusPath,
        kDbusInterface,
        "NameOwnerChanged",
        this,
        SLOT(handleNameOwnerChanged(QString,QString,QString))
    );

    connectBackendSignals();
    detectBackend();
}

QString WifiController::backendName() const {
    return m_backendName;
}

bool WifiController::supported() const {
    return m_supported;
}

bool WifiController::readOnly() const {
    return m_readOnly;
}

bool WifiController::available() const {
    return m_available;
}

bool WifiController::enabled() const {
    return m_enabled;
}

bool WifiController::busy() const {
    return m_busy;
}

bool WifiController::scanning() const {
    return m_scanning;
}

QString WifiController::currentSsid() const {
    return m_currentSsid;
}

QString WifiController::statusText() const {
    return m_statusText;
}

QString WifiController::infoMessage() const {
    return m_infoMessage;
}

QString WifiController::errorMessage() const {
    return m_errorMessage;
}

QString WifiController::unsupportedReason() const {
    return m_unsupportedReason;
}

QAbstractItemModel *WifiController::networks() {
    return &m_networks;
}

void WifiController::refreshState() {
    if (m_backendName == QLatin1String("networkmanager")
            || m_backendName == QLatin1String("iwd")) {
        refreshStateInternal();
        return;
    }

    detectBackend();
}

void WifiController::refreshNetworks(bool rescan) {
    refreshNetworksInternal(rescan, false);
}

void WifiController::setEnabled(bool enabled) {
    clearMessages();

    if (!m_supported) {
        setErrorMessage(m_unsupportedReason.isEmpty() ? QStringLiteral("Wi-Fi control is unavailable.") : m_unsupportedReason);
        return;
    }

    if (!m_available || !isValidPath(m_wifiDevicePath)) {
        setErrorMessage(QStringLiteral("No Wi-Fi device is available."));
        return;
    }

    invalidateRefresh();
    m_actionInProgress = true;
    updateBusyState();

    QString failure;
    bool changed = false;

    if (m_backendName == QLatin1String("iwd")) {
        changed = setProperty(
            kIwdService,
            m_wifiDevicePath,
            QString::fromLatin1(kIwdDeviceInterface),
            QStringLiteral("Powered"),
            enabled,
            &failure
        );
    } else {
        changed = setProperty(
            kNetworkManagerService,
            kNetworkManagerPath,
            kNetworkManagerInterface,
            QStringLiteral("WirelessEnabled"),
            enabled,
            &failure
        );
    }

    m_actionInProgress = false;
    updateBusyState();

    if (!changed) {
        setErrorMessage(failure.isEmpty() ? QStringLiteral("Unable to update Wi-Fi state.") : failure);
        return;
    }

    setInfoMessage(enabled ? QStringLiteral("Wi-Fi turned on.") : QStringLiteral("Wi-Fi turned off."));
    refreshStateInternal();
}

void WifiController::disconnectCurrent() {
    clearMessages();

    if (!m_supported) {
        setErrorMessage(m_unsupportedReason.isEmpty() ? QStringLiteral("Wi-Fi control is unavailable.") : m_unsupportedReason);
        return;
    }

    if (!m_available || !isValidPath(m_wifiDevicePath)) {
        setErrorMessage(QStringLiteral("No Wi-Fi device is available."));
        return;
    }

    invalidateRefresh();
    m_actionInProgress = true;
    updateBusyState();

    const QDBusMessage reply = m_backendName == QLatin1String("iwd")
        ? callMethod(
            kIwdService,
            m_wifiDevicePath,
            QString::fromLatin1(kIwdStationInterface),
            QStringLiteral("Disconnect")
        )
        : callMethod(
            kNetworkManagerService,
            m_wifiDevicePath,
            kNetworkManagerDeviceInterface,
            QStringLiteral("Disconnect")
        );

    m_actionInProgress = false;
    updateBusyState();

    if (reply.type() == QDBusMessage::ErrorMessage) {
        setErrorMessage(errorTextForReply(reply, QStringLiteral("Unable to disconnect Wi-Fi.")));
        return;
    }

    setInfoMessage(QStringLiteral("Disconnected from Wi-Fi."));
    refreshStateInternal();
}

void WifiController::connectToNetwork(const QString &ssid, const QString &password) {
    clearMessages();

    const QString trimmedSsid = ssid.trimmed();
    if (trimmedSsid.isEmpty()) {
        setErrorMessage(QStringLiteral("Hidden networks are not supported in this panel yet."));
        return;
    }

    if (!m_supported) {
        setErrorMessage(m_unsupportedReason.isEmpty() ? QStringLiteral("Wi-Fi control is unavailable.") : m_unsupportedReason);
        return;
    }

    if (!m_available || !isValidPath(m_wifiDevicePath)) {
        setErrorMessage(QStringLiteral("No Wi-Fi device is available."));
        return;
    }

    if (!m_enabled) {
        setErrorMessage(QStringLiteral("Turn on Wi-Fi first."));
        return;
    }

    const auto selectedNetwork = m_networks.networkForSsid(trimmedSsid);
    if (!selectedNetwork.has_value()) {
        setErrorMessage(QStringLiteral("Selected network is no longer available."));
        return;
    }

    if (selectedNetwork->connected)
        return;

    if (m_backendName == QLatin1String("iwd")) {
        const QString networkType = selectedNetwork->type.trimmed();
        if (networkType == QLatin1String("wep")) {
            setErrorMessage(QStringLiteral("WEP networks are not supported in this panel."));
            return;
        }

        if (networkType == QLatin1String("8021x") && !selectedNetwork->savedConnection) {
            setErrorMessage(QStringLiteral("Provision this 802.1X network in iwd first, then connect again."));
            return;
        }

        const bool needsAgent = selectedNetwork->secure && !selectedNetwork->savedConnection;
        if (needsAgent && password.trimmed().isEmpty()) {
            setErrorMessage(QStringLiteral("Enter a password first."));
            return;
        }

        if (needsAgent) {
            ensureIwdAgentRegistered();
            if (!m_iwdAgentRegistered) {
                setErrorMessage(
                    m_iwdAgentRegistrationError.isEmpty()
                        ? QStringLiteral("Unable to register the iwd passphrase agent.")
                        : m_iwdAgentRegistrationError
                );
                return;
            }
            m_iwdPendingPassphrases.insert(selectedNetwork->objectPath, password);
        }

        invalidateRefresh();
        m_actionInProgress = true;
        updateBusyState();

        const QDBusMessage reply = callMethod(
            kIwdService,
            selectedNetwork->objectPath,
            QString::fromLatin1(kIwdNetworkInterface),
            QStringLiteral("Connect")
        );

        m_actionInProgress = false;
        updateBusyState();
        m_iwdPendingPassphrases.remove(selectedNetwork->objectPath);

        if (reply.type() == QDBusMessage::ErrorMessage) {
            if (reply.errorName().endsWith(QLatin1String(".NoAgent")) && !m_iwdAgentRegistrationError.isEmpty()) {
                setErrorMessage(m_iwdAgentRegistrationError);
            } else if (reply.errorName().endsWith(QLatin1String(".NotConfigured"))
                    && networkType == QLatin1String("8021x")) {
                setErrorMessage(QStringLiteral("This enterprise network still needs to be provisioned in iwd."));
            } else {
                setErrorMessage(errorTextForReply(reply, QStringLiteral("Unable to connect to the selected Wi-Fi network.")));
            }
            return;
        }

        setInfoMessage(QStringLiteral("Connecting to %1...").arg(trimmedSsid));
        refreshStateInternal();
        return;
    }

    const QString accessPointPath = selectedNetwork->objectPath;
    invalidateRefresh();
    m_actionInProgress = true;
    updateBusyState();

    bool ok = false;
    if (selectedNetwork->savedConnection) {
        ok = activateSavedConnection(trimmedSsid, accessPointPath);
    } else {
        ok = addAndActivateConnection(trimmedSsid, accessPointPath, password, selectedNetwork->secure);
    }

    m_actionInProgress = false;
    updateBusyState();

    if (!ok)
        return;

    m_savedConnectionsDirty = true;
    setInfoMessage(QStringLiteral("Connecting to %1...").arg(trimmedSsid));
    refreshStateInternal();
}

void WifiController::clearMessages() {
    setInfoMessage({});
    setErrorMessage({});
}

void WifiController::handleNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &) {
    if (name == QLatin1String(kNetworkManagerService)
            || name == QLatin1String(kIwdService)
            || name == QLatin1String(kConnmanService)) {
        m_savedConnectionsDirty = true;
        if (name == QLatin1String(kIwdService) && !oldOwner.isEmpty()) {
            setIwdAgentRegisteredState(false);
            m_iwdPendingPassphrases.clear();
        }
        detectBackend();
    }
}

void WifiController::handleManagerPropertiesChanged(const QString &interfaceName, const QVariantMap &, const QStringList &) {
    if (interfaceName != QLatin1String(kNetworkManagerInterface))
        return;

    invalidateRefresh();
    m_stateRefreshTimer.start();
}

void WifiController::handleDevicePropertiesChanged(const QString &interfaceName, const QVariantMap &changedProperties, const QStringList &) {
    const bool relevant = m_backendName == QLatin1String("iwd")
        ? (interfaceName == QLatin1String(kIwdDeviceInterface) || interfaceName == QLatin1String(kIwdStationInterface))
        : (interfaceName == QLatin1String(kNetworkManagerDeviceInterface) || interfaceName == QLatin1String(kNetworkManagerWirelessInterface));
    if (!relevant)
        return;
    invalidateRefresh();
    if (m_backendName == QLatin1String("iwd")) {
        if (interfaceName == QLatin1String(kIwdDeviceInterface)) {
            m_stateRefreshTimer.start();
            return;
        }

        if (interfaceName != QLatin1String(kIwdStationInterface))
            return;

        if (changedProperties.contains(QStringLiteral("Scanning"))) {
            const bool scanning = changedProperties.value(QStringLiteral("Scanning")).toBool();
            setScanningState(scanning);
            if (scanning) {
                m_scanTimeoutTimer.start();
            } else {
                m_scanTimeoutTimer.stop();
            }
        }

        m_stateRefreshTimer.start();
        m_networkRefreshTimer.start();
        return;
    }

    if (interfaceName == QLatin1String(kNetworkManagerDeviceInterface)) {
        m_stateRefreshTimer.start();
        return;
    }

    if (interfaceName != QLatin1String(kNetworkManagerWirelessInterface))
        return;

    if (changedProperties.contains(QStringLiteral("LastScan"))) {
        setScanningState(false);
        m_scanTimeoutTimer.stop();
    }

    m_networkRefreshTimer.start();
}

void WifiController::handleAccessPointAdded(const QDBusObjectPath &) {
    invalidateRefresh();
    m_networkRefreshTimer.start();
}

void WifiController::handleAccessPointRemoved(const QDBusObjectPath &) {
    invalidateRefresh();
    m_networkRefreshTimer.start();
}

void WifiController::handleDeviceAdded(const QDBusObjectPath &) {
    invalidateRefresh();
    m_stateRefreshTimer.start();
}

void WifiController::handleDeviceRemoved(const QDBusObjectPath &) {
    invalidateRefresh();
    m_stateRefreshTimer.start();
}

void WifiController::handleIwdInterfacesAdded(const QDBusObjectPath &, const ConnectionSettingsMap &) {
    if (m_backendName != QLatin1String("iwd"))
        return;

    invalidateRefresh();
    m_stateRefreshTimer.start();
    m_networkRefreshTimer.start();
}

void WifiController::handleIwdInterfacesRemoved(const QDBusObjectPath &, const QStringList &) {
    if (m_backendName != QLatin1String("iwd"))
        return;

    invalidateRefresh();
    m_stateRefreshTimer.start();
    m_networkRefreshTimer.start();
}

void WifiController::handleNewConnection(const QDBusObjectPath &) {
    invalidateRefresh();
    m_savedConnectionsDirty = true;
    m_stateRefreshTimer.start();
    m_networkRefreshTimer.start();
}

void WifiController::handleConnectionRemoved(const QDBusObjectPath &) {
    invalidateRefresh();
    m_savedConnectionsDirty = true;
    m_stateRefreshTimer.start();
    m_networkRefreshTimer.start();
}

void WifiController::connectBackendSignals() {
    if (!m_managerSignalsConnected) {
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            kNetworkManagerPath,
            kDbusPropertiesInterface,
            "PropertiesChanged",
            this,
            SLOT(handleManagerPropertiesChanged(QString,QVariantMap,QStringList))
        );
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            kNetworkManagerPath,
            kNetworkManagerInterface,
            "DeviceAdded",
            this,
            SLOT(handleDeviceAdded(QDBusObjectPath))
        );
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            kNetworkManagerPath,
            kNetworkManagerInterface,
            "DeviceRemoved",
            this,
            SLOT(handleDeviceRemoved(QDBusObjectPath))
        );
        m_managerSignalsConnected = true;
    }

    if (!m_settingsSignalsConnected) {
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            kNetworkManagerSettingsPath,
            kNetworkManagerSettingsInterface,
            "NewConnection",
            this,
            SLOT(handleNewConnection(QDBusObjectPath))
        );
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            kNetworkManagerSettingsPath,
            kNetworkManagerSettingsInterface,
            "ConnectionRemoved",
            this,
            SLOT(handleConnectionRemoved(QDBusObjectPath))
        );
        m_settingsSignalsConnected = true;
    }

    if (!m_iwdSignalsConnected) {
        QDBusConnection::systemBus().connect(
            kIwdService,
            kRootPath,
            kObjectManagerInterface,
            "InterfacesAdded",
            this,
            SLOT(handleIwdInterfacesAdded(QDBusObjectPath,ConnectionSettingsMap))
        );
        QDBusConnection::systemBus().connect(
            kIwdService,
            kRootPath,
            kObjectManagerInterface,
            "InterfacesRemoved",
            this,
            SLOT(handleIwdInterfacesRemoved(QDBusObjectPath,QStringList))
        );
        m_iwdSignalsConnected = true;
    }

}

WifiController::~WifiController() {
    if (m_refreshCancellation)
        m_refreshCancellation->store(true);
}

void WifiController::invalidateRefresh() {
    ++m_refreshGeneration;
    if (m_refreshCancellation)
        m_refreshCancellation->store(true);
}

void WifiController::detectBackend() {
    requestRefresh(false, true);
}

void WifiController::refreshStateInternal() {
    requestRefresh(false, false);
}

void WifiController::refreshNetworksInternal(bool rescan, bool triggeredBySignal) {
    requestRefresh(rescan, !triggeredBySignal);
}

void WifiController::requestRefresh(bool rescan, bool reportErrors) {
    invalidateRefresh();
    m_refreshPending = true;
    m_rescanPending = m_rescanPending || rescan;
    m_reportRefreshErrors = m_reportRefreshErrors || reportErrors;
    if (rescan) {
        clearMessages();
        setScanningState(true);
        m_scanTimeoutTimer.start();
    }
    startPendingRefresh();
}

void WifiController::startPendingRefresh() {
    if (m_refreshRunning || !m_refreshPending)
        return;

    WifiRefreshRequest request;
    request.backendName = m_backendName;
    request.savedConnections = m_savedConnectionsBySsid;
    request.reloadSavedConnections = m_savedConnectionsDirty;
    request.rescan = std::exchange(m_rescanPending, false);
    request.scanning = m_scanning;
    request.cancellation = std::make_shared<std::atomic_bool>(false);
    m_refreshCancellation = request.cancellation;
    const auto generation = m_refreshGeneration;
    const bool reportErrors = std::exchange(m_reportRefreshErrors, false);
    m_refreshPending = false;
    m_refreshRunning = true;

    auto *watcher = new QFutureWatcher<WifiRefreshSnapshot>(this);
    connect(watcher, &QFutureWatcher<WifiRefreshSnapshot>::finished, this,
            [this, watcher, generation, reportErrors, request]() {
        const auto snapshot = watcher->result();
        watcher->deleteLater();
        m_refreshRunning = false;
        if (generation == m_refreshGeneration) {
            applyRefreshSnapshot(snapshot);
            if (reportErrors && !snapshot.error.isEmpty())
                setErrorMessage(snapshot.error);
        } else {
            m_reportRefreshErrors = m_reportRefreshErrors || reportErrors;
            if (request.rescan && !snapshot.scanAttempted)
                m_rescanPending = true;
        }
        startPendingRefresh();
    });
    watcher->setFuture(QtConcurrent::run([request]() {
        return WifiSnapshotReader(request).read();
    }));
}

void WifiController::applyRefreshSnapshot(const WifiRefreshSnapshot &snapshot) {
    if (!snapshot.stateValid)
        return;
    const bool backendChanged = m_backendName != snapshot.backendName;
    if (backendChanged) {
        unregisterIwdAgent();
        m_iwdPendingPassphrases.clear();
        m_savedConnectionsBySsid.clear();
        m_savedConnectionsDirty = true;
    }
    setBackendName(snapshot.backendName);
    if (backendChanged || m_wifiDevicePath != snapshot.devicePath) {
        m_wifiDevicePath = snapshot.devicePath;
        reconnectDeviceSignals(m_wifiDevicePath);
    }
    setSupported(snapshot.supported);
    setReadOnly(!snapshot.supported);
    setUnsupportedReason(snapshot.unsupportedReason);
    setAvailable(snapshot.available);
    setEnabledState(snapshot.enabled);
    setCurrentSsid(snapshot.currentSsid);
    setScanningState(snapshot.scanning);
    if (snapshot.scanning) {
        if (!m_scanTimeoutTimer.isActive())
            m_scanTimeoutTimer.start();
    } else {
        m_scanTimeoutTimer.stop();
    }
    if (snapshot.savedConnectionsRefreshed) {
        m_savedConnectionsBySsid = snapshot.savedConnections;
        m_savedConnectionsDirty = false;
    }
    if (snapshot.networksValid)
        m_networks.setNetworks(snapshot.networks);
    if (!snapshot.currentSsid.isEmpty() && m_infoMessage.startsWith(QStringLiteral("Connecting to ")))
        setInfoMessage({});
    updateStatusText();
}

void WifiController::reconnectDeviceSignals(const QString &devicePath) {
    const QString backend = m_backendName;
    if (m_connectedDeviceSignalPath == devicePath && m_connectedDeviceSignalBackend == backend)
        return;

    disconnectDeviceSignals();

    if (!isValidPath(devicePath))
        return;

    if (backend == QLatin1String("iwd")) {
        QDBusConnection::systemBus().connect(
            kIwdService,
            devicePath,
            kDbusPropertiesInterface,
            "PropertiesChanged",
            this,
            SLOT(handleDevicePropertiesChanged(QString,QVariantMap,QStringList))
        );
    } else {
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            devicePath,
            kDbusPropertiesInterface,
            "PropertiesChanged",
            this,
            SLOT(handleDevicePropertiesChanged(QString,QVariantMap,QStringList))
        );
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            devicePath,
            kNetworkManagerWirelessInterface,
            "AccessPointAdded",
            this,
            SLOT(handleAccessPointAdded(QDBusObjectPath))
        );
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            devicePath,
            kNetworkManagerWirelessInterface,
            "AccessPointRemoved",
            this,
            SLOT(handleAccessPointRemoved(QDBusObjectPath))
        );
    }

    m_connectedDeviceSignalPath = devicePath;
    m_connectedDeviceSignalBackend = backend;
}

void WifiController::disconnectDeviceSignals() {
    if (m_connectedDeviceSignalPath.isEmpty())
        return;

    if (m_connectedDeviceSignalBackend == QLatin1String("iwd")) {
        QDBusConnection::systemBus().disconnect(
            kIwdService,
            m_connectedDeviceSignalPath,
            kDbusPropertiesInterface,
            "PropertiesChanged",
            this,
            SLOT(handleDevicePropertiesChanged(QString,QVariantMap,QStringList))
        );
    } else {
        QDBusConnection::systemBus().disconnect(
            kNetworkManagerService,
            m_connectedDeviceSignalPath,
            kDbusPropertiesInterface,
            "PropertiesChanged",
            this,
            SLOT(handleDevicePropertiesChanged(QString,QVariantMap,QStringList))
        );
        QDBusConnection::systemBus().disconnect(
            kNetworkManagerService,
            m_connectedDeviceSignalPath,
            kNetworkManagerWirelessInterface,
            "AccessPointAdded",
            this,
            SLOT(handleAccessPointAdded(QDBusObjectPath))
        );
        QDBusConnection::systemBus().disconnect(
            kNetworkManagerService,
            m_connectedDeviceSignalPath,
            kNetworkManagerWirelessInterface,
            "AccessPointRemoved",
            this,
            SLOT(handleAccessPointRemoved(QDBusObjectPath))
        );
    }

    m_connectedDeviceSignalPath.clear();
    m_connectedDeviceSignalBackend.clear();
}

void WifiController::ensureIwdAgentRegistered() {
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        setIwdAgentRegisteredState(false);
        setIwdAgentRegistrationError(QStringLiteral("The system D-Bus is unavailable."));
        return;
    }

    if (!m_iwdAgent)
        m_iwdAgent = new IwdAgent(this);

    if (!m_iwdAgentObjectExported) {
        m_iwdAgentObjectExported = bus.registerObject(
            QString::fromLatin1(kIwdAgentObjectPath),
            m_iwdAgent,
            QDBusConnection::ExportAllSlots
        );

        if (!m_iwdAgentObjectExported) {
            setIwdAgentRegisteredState(false);
            setIwdAgentRegistrationError(QStringLiteral("Failed to export the iwd passphrase agent."));
            return;
        }
    }

    QDBusConnectionInterface *connectionInterface = bus.interface();
    if (!connectionInterface || !connectionInterface->isServiceRegistered(QString::fromLatin1(kIwdService))) {
        setIwdAgentRegisteredState(false);
        setIwdAgentRegistrationError({});
        return;
    }

    QDBusInterface manager(
        QString::fromLatin1(kIwdService),
        QString::fromLatin1(kIwdAgentManagerPath),
        QString::fromLatin1(kIwdAgentManagerInterface),
        bus
    );

    if (!manager.isValid()) {
        setIwdAgentRegisteredState(false);
        setIwdAgentRegistrationError(QStringLiteral("iwd is unavailable."));
        return;
    }

    manager.call(
        QStringLiteral("UnregisterAgent"),
        QVariant::fromValue(QDBusObjectPath(QString::fromLatin1(kIwdAgentObjectPath)))
    );

    QDBusReply<void> reply = manager.call(
        QStringLiteral("RegisterAgent"),
        QVariant::fromValue(QDBusObjectPath(QString::fromLatin1(kIwdAgentObjectPath)))
    );

    if (!reply.isValid()) {
        setIwdAgentRegisteredState(false);
        setIwdAgentRegistrationError(reply.error().message());
        return;
    }

    setIwdAgentRegistrationError({});
    setIwdAgentRegisteredState(true);
}

void WifiController::unregisterIwdAgent() {
    if (!m_iwdAgentRegistered)
        return;

    auto message = QDBusMessage::createMethodCall(kIwdService, kIwdAgentManagerPath,
                                                kIwdAgentManagerInterface, QStringLiteral("UnregisterAgent"));
    message.setArguments({QVariant::fromValue(QDBusObjectPath(QString::fromLatin1(kIwdAgentObjectPath)))});
    message.setAutoStartService(false);
    QDBusConnection::systemBus().asyncCall(message, 1500);

    setIwdAgentRegisteredState(false);
}

void WifiController::setIwdAgentRegisteredState(bool registered) {
    m_iwdAgentRegistered = registered;
}

void WifiController::setIwdAgentRegistrationError(const QString &error) {
    m_iwdAgentRegistrationError = error;
}

QString WifiController::takeIwdPassphraseForNetwork(const QString &networkPath) {
    return m_iwdPendingPassphrases.take(networkPath);
}

bool WifiController::setProperty(const QString &service, const QString &path, const QString &interfaceName, const QString &propertyName, const QVariant &value, QString *errorMessage) const {
    const QDBusMessage reply = callMethod(
        service,
        path,
        kDbusPropertiesInterface,
        QStringLiteral("Set"),
        {interfaceName, propertyName, QVariant::fromValue(QDBusVariant(value))}
    );

    if (reply.type() == QDBusMessage::ErrorMessage) {
        if (errorMessage)
            *errorMessage = errorTextForReply(reply, QStringLiteral("Unable to update Wi-Fi state."));
        return false;
    }

    return true;
}

QDBusMessage WifiController::callMethod(const QString &service, const QString &path, const QString &interfaceName, const QString &methodName, const QList<QVariant> &arguments) const {
    QDBusMessage message = QDBusMessage::createMethodCall(service, path, interfaceName, methodName);
    message.setArguments(arguments);
    return QDBusConnection::systemBus().call(message);
}

void WifiController::setBackendName(const QString &backendName) {
    if (m_backendName == backendName)
        return;

    m_backendName = backendName;
    emit backendNameChanged();
    updateStatusText();
}

void WifiController::setSupported(bool supported) {
    if (m_supported == supported)
        return;

    m_supported = supported;
    emit supportedChanged();
    updateStatusText();
}

void WifiController::setReadOnly(bool readOnly) {
    if (m_readOnly == readOnly)
        return;

    m_readOnly = readOnly;
    emit readOnlyChanged();
}

void WifiController::setAvailable(bool available) {
    if (m_available == available)
        return;

    m_available = available;
    emit availableChanged();
    updateStatusText();
}

void WifiController::setEnabledState(bool enabled) {
    if (m_enabled == enabled)
        return;

    m_enabled = enabled;
    emit enabledChanged();
    updateStatusText();
}

void WifiController::setBusyState(bool busy) {
    if (m_busy == busy)
        return;

    m_busy = busy;
    emit busyChanged();
    updateStatusText();
}

void WifiController::setScanningState(bool scanning) {
    if (m_scanning == scanning)
        return;

    m_scanning = scanning;
    emit scanningChanged();
    updateBusyState();
}

void WifiController::setCurrentSsid(const QString &currentSsid) {
    if (m_currentSsid == currentSsid)
        return;

    m_currentSsid = currentSsid;
    emit currentSsidChanged();
    updateStatusText();
}

void WifiController::setStatusText(const QString &statusText) {
    if (m_statusText == statusText)
        return;

    m_statusText = statusText;
    emit statusTextChanged();
}

void WifiController::setInfoMessage(const QString &infoMessage) {
    if (m_infoMessage == infoMessage)
        return;

    m_infoMessage = infoMessage;
    emit infoMessageChanged();
}

void WifiController::setErrorMessage(const QString &errorMessage) {
    if (m_errorMessage == errorMessage)
        return;

    m_errorMessage = errorMessage;
    emit errorMessageChanged();
}

void WifiController::setUnsupportedReason(const QString &unsupportedReason) {
    if (m_unsupportedReason == unsupportedReason)
        return;

    m_unsupportedReason = unsupportedReason;
    emit unsupportedReasonChanged();
}

void WifiController::updateBusyState() {
    setBusyState(m_actionInProgress || m_scanning);
}

void WifiController::updateStatusText() {
    QString nextStatus;

    if (!m_supported) {
        if (m_backendName == QLatin1String("iwd"))
            nextStatus = QStringLiteral("iwd detected");
        else if (m_backendName == QLatin1String("connman"))
            nextStatus = QStringLiteral("ConnMan detected");
        else
            nextStatus = QStringLiteral("Unavailable");
    } else if (!m_available) {
        nextStatus = QStringLiteral("No device");
    } else if (!m_enabled) {
        nextStatus = QStringLiteral("Off");
    } else if (!m_currentSsid.isEmpty()) {
        nextStatus = m_currentSsid;
    } else if (m_scanning) {
        nextStatus = QStringLiteral("Scanning");
    } else if (m_busy) {
        nextStatus = QStringLiteral("Working...");
    } else {
        nextStatus = QStringLiteral("On");
    }

    setStatusText(nextStatus);
}

QString WifiController::errorTextForReply(const QDBusMessage &reply, const QString &fallback) const {
    if (reply.type() != QDBusMessage::ErrorMessage)
        return fallback;

    const QString message = reply.errorMessage().trimmed();
    if (!message.isEmpty())
        return message;

    const QString errorName = reply.errorName().trimmed();
    if (!errorName.isEmpty())
        return errorName;

    return fallback;
}

bool WifiController::activateSavedConnection(const QString &ssid, const QString &accessPointPath) {
    const QString connectionPath = m_savedConnectionsBySsid.value(ssid);
    if (!isValidPath(connectionPath)) {
        setErrorMessage(QStringLiteral("Saved Wi-Fi connection details are unavailable."));
        return false;
    }

    const QString specificObjectPath = isValidPath(accessPointPath) ? accessPointPath : QString::fromLatin1(kRootPath);
    const QDBusMessage reply = callMethod(
        kNetworkManagerService,
        kNetworkManagerPath,
        kNetworkManagerInterface,
        QStringLiteral("ActivateConnection"),
        {
            QVariant::fromValue(QDBusObjectPath(connectionPath)),
            QVariant::fromValue(QDBusObjectPath(m_wifiDevicePath)),
            QVariant::fromValue(QDBusObjectPath(specificObjectPath))
        }
    );

    if (reply.type() == QDBusMessage::ErrorMessage) {
        setErrorMessage(errorTextForReply(reply, QStringLiteral("Unable to activate the saved Wi-Fi connection.")));
        return false;
    }

    return true;
}

bool WifiController::addAndActivateConnection(const QString &ssid, const QString &accessPointPath, const QString &password, bool secure) {
    if (!isValidPath(accessPointPath)) {
        setErrorMessage(QStringLiteral("Selected network is no longer available."));
        return false;
    }

    if (secure && password.trimmed().isEmpty()) {
        setErrorMessage(QStringLiteral("Enter a password first."));
        return false;
    }

    ConnectionSettingsMap settings;

    QVariantMap connectionSection;
    connectionSection.insert(QStringLiteral("id"), ssid);
    connectionSection.insert(QStringLiteral("type"), QStringLiteral("802-11-wireless"));
    connectionSection.insert(QStringLiteral("uuid"), QUuid::createUuid().toString(QUuid::WithoutBraces));
    connectionSection.insert(QStringLiteral("autoconnect"), false);
    settings.insert(QStringLiteral("connection"), connectionSection);

    QVariantMap wirelessSection;
    wirelessSection.insert(QStringLiteral("ssid"), QByteArray(ssid.toUtf8()));
    wirelessSection.insert(QStringLiteral("mode"), QStringLiteral("infrastructure"));
    settings.insert(QStringLiteral("802-11-wireless"), wirelessSection);

    QVariantMap ipv4Section;
    ipv4Section.insert(QStringLiteral("method"), QStringLiteral("auto"));
    settings.insert(QStringLiteral("ipv4"), ipv4Section);

    QVariantMap ipv6Section;
    ipv6Section.insert(QStringLiteral("method"), QStringLiteral("auto"));
    settings.insert(QStringLiteral("ipv6"), ipv6Section);

    if (secure) {
        QVariantMap securitySection;
        securitySection.insert(QStringLiteral("key-mgmt"), QStringLiteral("wpa-psk"));
        securitySection.insert(QStringLiteral("psk"), password);
        settings.insert(QStringLiteral("802-11-wireless-security"), securitySection);
    }

    const QDBusMessage reply = callMethod(
        kNetworkManagerService,
        kNetworkManagerPath,
        kNetworkManagerInterface,
        QStringLiteral("AddAndActivateConnection"),
        {
            QVariant::fromValue(settings),
            QVariant::fromValue(QDBusObjectPath(m_wifiDevicePath)),
            QVariant::fromValue(QDBusObjectPath(accessPointPath))
        }
    );

    if (reply.type() == QDBusMessage::ErrorMessage) {
        setErrorMessage(errorTextForReply(reply, QStringLiteral("Unable to connect to the selected Wi-Fi network.")));
        return false;
    }

    return true;
}

#include "WifiController.moc"
