#include "CompositorBackend.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QVariant>

#include <algorithm>

namespace {
QString normalizedCompositorName(const QString &value)
{
    const QString text = value.trimmed().toLower();
    if (text == QLatin1String("niri"))
        return QStringLiteral("niri");
    if (text == QLatin1String("hyprland") || text == QLatin1String("hypr"))
        return QStringLiteral("hyprland");
    return QString();
}

bool desktopEnvironmentContains(const QString &desktopNames, const QString &desktop)
{
    const QStringList names = desktopNames.split(u':', Qt::SkipEmptyParts);
    for (const QString &name : names) {
        if (name.trimmed().compare(desktop, Qt::CaseInsensitive) == 0)
            return true;
    }
    return false;
}

quint64 jsonU64(const QJsonValue &value)
{
    bool ok = false;
    const quint64 integer = value.toVariant().toULongLong(&ok);
    if (ok)
        return integer;

    const double number = value.toDouble(-1.0);
    return number >= 0.0 ? static_cast<quint64>(number) : 0;
}

}

CompositorBackend::CompositorBackend(QObject *parent)
    : QObject(parent)
{
#if TIDE_ISLAND_WITH_NIRI
    m_niriReconnectTimer.setSingleShot(true);
    m_niriReconnectTimer.setInterval(2000);
    connect(&m_niriReconnectTimer, &QTimer::timeout, this, &CompositorBackend::connectNiriEventStream);
#endif

    detectCompositor();
}

CompositorBackend::~CompositorBackend()
{
#if TIDE_ISLAND_WITH_NIRI
    stopNiriEventStream();
#endif
}

QString CompositorBackend::compositor() const
{
    return m_compositor;
}

QString CompositorBackend::focusedOutputName() const
{
    return m_focusedOutputName;
}

int CompositorBackend::revision() const
{
    return m_revision;
}

int CompositorBackend::activeWorkspaceIndexForOutput(const QString &outputName) const
{
    const QString normalizedOutput = outputName.trimmed();
    if (!normalizedOutput.isEmpty()) {
        const auto exactIt = m_niriActiveWorkspaceByOutput.constFind(normalizedOutput);
        if (exactIt != m_niriActiveWorkspaceByOutput.cend())
            return exactIt.value();
    }

    const auto focusedIt = m_niriActiveWorkspaceByOutput.constFind(m_focusedOutputName);
    if (focusedIt != m_niriActiveWorkspaceByOutput.cend())
        return focusedIt.value();

    if (m_niriActiveWorkspaceByOutput.size() == 1)
        return m_niriActiveWorkspaceByOutput.constBegin().value();

    return 1;
}

bool CompositorBackend::isOutputFocused(const QString &outputName) const
{
    const QString normalizedOutput = outputName.trimmed();
    if (m_compositor != QLatin1String("niri"))
        return false;

    if (normalizedOutput.isEmpty())
        return true;
    if (m_focusedOutputName.isEmpty())
        return false;

    return normalizedOutput == m_focusedOutputName;
}

bool CompositorBackend::applyNiriEventJson(const QByteArray &line)
{
#if TIDE_ISLAND_WITH_NIRI
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(line.trimmed(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return false;

    const QJsonObject event = document.object();
    if (event.contains(QStringLiteral("WorkspacesChanged"))) {
        const QJsonObject payload = event.value(QStringLiteral("WorkspacesChanged")).toObject();
        applyNiriWorkspacesChanged(payload.value(QStringLiteral("workspaces")).toArray());
        return true;
    }

    if (event.contains(QStringLiteral("WorkspaceActivated"))) {
        applyNiriWorkspaceActivated(event.value(QStringLiteral("WorkspaceActivated")).toObject());
        return true;
    }

    return false;
#else
    Q_UNUSED(line)
    return false;
#endif
}

void CompositorBackend::detectCompositor()
{
    const QString requested = normalizedCompositorName(QString::fromLocal8Bit(qgetenv("TIDE_ISLAND_COMPOSITOR")));
    if (!requested.isEmpty()) {
#if TIDE_ISLAND_WITH_NIRI
        if (requested == QLatin1String("niri")) {
            setCompositor(QStringLiteral("niri"));
            startNiriEventStream();
            return;
        }
#endif
        setCompositor(QStringLiteral("hyprland"));
        return;
    }

#if TIDE_ISLAND_WITH_NIRI
    if (desktopEnvironmentContains(
            QString::fromLocal8Bit(qgetenv("XDG_CURRENT_DESKTOP")),
            QStringLiteral("niri"))) {
        setCompositor(QStringLiteral("niri"));
        startNiriEventStream();
        return;
    }

    // A compositor started from another compositor can inherit the parent's
    // socket variables. The desktop name describes the current session, so it
    // must win over a stale NIRI_SOCKET inherited by a Hyprland session.
    if (desktopEnvironmentContains(
            QString::fromLocal8Bit(qgetenv("XDG_CURRENT_DESKTOP")),
            QStringLiteral("hyprland"))) {
        setCompositor(QStringLiteral("hyprland"));
        return;
    }

    if (hasNiriSocket()) {
        setCompositor(QStringLiteral("niri"));
        startNiriEventStream();
        return;
    }
#endif

    setCompositor(QStringLiteral("hyprland"));
}

void CompositorBackend::setCompositor(const QString &compositor)
{
    if (m_compositor == compositor)
        return;

    m_compositor = compositor;
    emit compositorChanged();
}

void CompositorBackend::setFocusedOutputName(const QString &outputName)
{
    if (m_focusedOutputName == outputName)
        return;

    m_focusedOutputName = outputName;
    emit focusedOutputNameChanged();
}

void CompositorBackend::bumpRevision()
{
    ++m_revision;
    emit revisionChanged();
}

#if TIDE_ISLAND_WITH_NIRI
bool CompositorBackend::hasNiriSocket() const
{
    return !qEnvironmentVariableIsEmpty("NIRI_SOCKET");
}

void CompositorBackend::startNiriEventStream()
{
    m_niriSocketPath = QString::fromLocal8Bit(qgetenv("NIRI_SOCKET"));
    if (m_niriSocketPath.isEmpty())
        return;

    connectNiriEventStream();
}

void CompositorBackend::connectNiriEventStream()
{
    if (m_compositor != QLatin1String("niri") || m_niriSocketPath.isEmpty())
        return;
    if (m_niriEventSocket && m_niriEventSocket->state() != QLocalSocket::UnconnectedState)
        return;

    if (m_niriEventSocket)
        m_niriEventSocket->deleteLater();

    m_niriEventSocket = new QLocalSocket(this);
    connect(m_niriEventSocket, &QLocalSocket::connected, this, [this]() {
        m_niriEventBuffer.clear();
        m_niriEventSocket->write("\"EventStream\"\n");
        m_niriEventSocket->flush();
    });
    connect(m_niriEventSocket, &QLocalSocket::readyRead, this, &CompositorBackend::handleNiriEventBytes);
    connect(m_niriEventSocket, &QLocalSocket::disconnected, this, [this]() {
        if (m_compositor == QLatin1String("niri") && !m_niriReconnectTimer.isActive())
            m_niriReconnectTimer.start();
    });
    connect(m_niriEventSocket, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
        if (m_niriEventSocket)
            m_niriEventSocket->abort();
        if (m_compositor == QLatin1String("niri") && !m_niriReconnectTimer.isActive())
            m_niriReconnectTimer.start();
    });

    m_niriEventSocket->connectToServer(m_niriSocketPath);
}

void CompositorBackend::stopNiriEventStream()
{
    m_niriReconnectTimer.stop();
    if (!m_niriEventSocket)
        return;

    m_niriEventSocket->disconnect(this);
    m_niriEventSocket->abort();
    m_niriEventSocket->deleteLater();
    m_niriEventSocket = nullptr;
}

void CompositorBackend::handleNiriEventBytes()
{
    if (!m_niriEventSocket)
        return;

    m_niriEventBuffer.append(m_niriEventSocket->readAll());
    while (true) {
        const qsizetype newlineIndex = m_niriEventBuffer.indexOf('\n');
        if (newlineIndex < 0)
            break;

        const QByteArray line = m_niriEventBuffer.left(newlineIndex).trimmed();
        m_niriEventBuffer.remove(0, newlineIndex + 1);
        handleNiriEventLine(line);
    }
}

void CompositorBackend::handleNiriEventLine(const QByteArray &line)
{
    if (!line.isEmpty())
        applyNiriEventJson(line);
}

void CompositorBackend::applyNiriWorkspacesChanged(const QJsonArray &workspaces)
{
    QHash<quint64, NiriWorkspaceState> nextWorkspaces;
    QHash<QString, int> nextActiveByOutput;
    QString nextFocusedOutput;

    for (const QJsonValue &value : workspaces) {
        const QJsonObject object = value.toObject();
        const quint64 id = jsonU64(object.value(QStringLiteral("id")));
        if (id == 0)
            continue;

        NiriWorkspaceState state;
        state.id = id;
        state.index = std::max(1, object.value(QStringLiteral("idx")).toInt(1));
        state.outputName = object.value(QStringLiteral("output")).toString();
        state.active = object.value(QStringLiteral("is_active")).toBool(false);
        state.focused = object.value(QStringLiteral("is_focused")).toBool(false);

        if (state.active)
            nextActiveByOutput.insert(state.outputName, state.index);
        if (state.focused)
            nextFocusedOutput = state.outputName;

        nextWorkspaces.insert(id, state);
    }

    m_niriWorkspaces = nextWorkspaces;
    m_niriActiveWorkspaceByOutput = nextActiveByOutput;
    setFocusedOutputName(nextFocusedOutput);
    bumpRevision();
}

void CompositorBackend::applyNiriWorkspaceActivated(const QJsonObject &event)
{
    const quint64 id = jsonU64(event.value(QStringLiteral("id")));
    auto it = m_niriWorkspaces.find(id);
    if (it == m_niriWorkspaces.end())
        return;

    const QString outputName = it.value().outputName;
    for (auto workspaceIt = m_niriWorkspaces.begin(); workspaceIt != m_niriWorkspaces.end(); ++workspaceIt) {
        if (workspaceIt.value().outputName == outputName)
            workspaceIt.value().active = false;
        if (event.value(QStringLiteral("focused")).toBool(false))
            workspaceIt.value().focused = false;
    }

    it.value().active = true;
    m_niriActiveWorkspaceByOutput.insert(outputName, it.value().index);

    if (event.value(QStringLiteral("focused")).toBool(false)) {
        it.value().focused = true;
        setFocusedOutputName(outputName);
    }

    bumpRevision();
}

#endif
