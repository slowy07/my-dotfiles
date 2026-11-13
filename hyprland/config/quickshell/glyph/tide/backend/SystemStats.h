#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QSet>
#include <QTimer>
#include <QtQml/qqml.h>
#include <functional>

class SystemStats final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(double cpuUsage READ cpuUsage NOTIFY statsChanged FINAL)
    Q_PROPERTY(double ramUsage READ ramUsage NOTIFY statsChanged FINAL)
    Q_PROPERTY(double storageUsage READ storageUsage NOTIFY storageChanged FINAL)
    Q_PROPERTY(QString statsError READ statsError NOTIFY statsChanged FINAL)
    Q_PROPERTY(QString storageError READ storageError NOTIFY storageChanged FINAL)

public:
    // A worker returns values only; it never touches a QObject or CPU baseline.
    struct Snapshot {
        quint64 cpuTotal = 0;
        quint64 cpuIdle = 0;
        bool cpuValid = false;
        double ramUsage = -1;
        qint64 bytesTotal = 0;
        qint64 bytesFree = 0;
        qint64 bytesAvailable = 0;
        bool storageValid = false;
        QString statsError;
        QString storageError;
    };
    using SnapshotReader = std::function<Snapshot(bool stats, bool storage)>;

    explicit SystemStats(QObject *parent = nullptr);
    explicit SystemStats(SnapshotReader reader, QObject *parent = nullptr);

    double cpuUsage() const { return m_cpuUsage; }
    double ramUsage() const { return m_ramUsage; }
    double storageUsage() const { return m_storageUsage; }
    QString statsError() const { return m_statsError; }
    QString storageError() const { return m_storageError; }

    Q_INVOKABLE void setClientActive(const QString &clientId, bool stats, bool storage);
    Q_INVOKABLE void refresh();

    static Snapshot readSnapshot(bool stats, bool storage,
                                 const QString &procDirectory = QStringLiteral("/proc"),
                                 const QString &storagePath = QStringLiteral("/"));

signals:
    void statsChanged();
    void storageChanged();

private:
    void queueSample(bool stats, bool storage);
    void startPendingSample();
    void applyStats(const Snapshot &snapshot);
    void applyStorage(const Snapshot &snapshot);

    SnapshotReader m_reader;
    QSet<QString> m_statsClients;
    QSet<QString> m_storageClients;
    QTimer m_statsTimer;
    QTimer m_storageTimer;
    QTimer m_dispatchTimer;
    QElapsedTimer m_clock;
    qint64 m_lastStatsMs = -1;
    qint64 m_lastStorageMs = -1;
    quint64 m_statsGeneration = 0;
    quint64 m_storageGeneration = 0;
    bool m_running = false;
    bool m_statsRunning = false;
    bool m_storageRunning = false;
    bool m_statsPending = false;
    bool m_storagePending = false;
    bool m_haveCpuBaseline = false;
    quint64 m_lastCpuTotal = 0;
    quint64 m_lastCpuIdle = 0;
    double m_cpuUsage = -1;
    double m_ramUsage = -1;
    double m_storageUsage = -1;
    QString m_statsError;
    QString m_storageError;
};
