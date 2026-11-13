#include "SystemStats.h"

#include <QDir>
#include <QFile>
#include <QFutureWatcher>
#include <QStorageInfo>
#include <QtConcurrent/QtConcurrentRun>
#include <algorithm>
#include <cmath>
#include <limits>
#include <utility>

namespace {
constexpr int statsIntervalMs = 3000;
constexpr int storageIntervalMs = 10000;

bool readCpu(const QByteArray &line, SystemStats::Snapshot &snapshot) {
    const auto parts = line.simplified().split(' ');
    if (parts.size() < 5 || parts.first() != "cpu")
        return false;
    quint64 total = 0;
    quint64 idle = 0;
    // guest/guest_nice are already included in user/nice; sum only the first
    // eight counters to avoid counting guest time twice.
    for (qsizetype i = 1; i < std::min(qsizetype(9), parts.size()); ++i) {
        bool ok = false;
        const auto value = parts.at(i).toULongLong(&ok);
        if (!ok || value > std::numeric_limits<quint64>::max() - total)
            return false;
        total += value;
        if (i == 4 || i == 5)
            idle += value;
    }
    snapshot.cpuTotal = total;
    snapshot.cpuIdle = idle;
    snapshot.cpuValid = true;
    return true;
}

double readRam(const QByteArray &contents) {
    qint64 total = -1;
    qint64 available = -1;
    for (const auto &line : contents.split('\n')) {
        const auto parts = line.simplified().split(' ');
        if (parts.size() < 2 || (parts.first() != "MemTotal:" && parts.first() != "MemAvailable:"))
            continue;
        bool ok = false;
        const auto value = parts.at(1).toLongLong(&ok);
        if (!ok || value < 0)
            return -1;
        if (parts.first() == "MemTotal:") total = value;
        else available = value;
    }
    return total > 0 && available >= 0 && available <= total
        ? double(total - available) / double(total) : -1;
}
}

SystemStats::SystemStats(QObject *parent)
    : SystemStats([](bool stats, bool storage) { return readSnapshot(stats, storage); }, parent) {}

SystemStats::SystemStats(SnapshotReader reader, QObject *parent)
    : QObject(parent), m_reader(std::move(reader)) {
    m_clock.start();
    m_statsTimer.setInterval(statsIntervalMs);
    m_statsTimer.setSingleShot(true);
    m_storageTimer.setInterval(storageIntervalMs);
    m_storageTimer.setSingleShot(true);
    m_dispatchTimer.setSingleShot(true);
    m_dispatchTimer.setInterval(0);
    connect(&m_statsTimer, &QTimer::timeout, this, [this]() { queueSample(true, false); });
    connect(&m_storageTimer, &QTimer::timeout, this, [this]() { queueSample(false, true); });
    connect(&m_dispatchTimer, &QTimer::timeout, this, &SystemStats::startPendingSample);
}

void SystemStats::setClientActive(const QString &clientId, bool stats, bool storage) {
    if (clientId.isEmpty())
        return;
    const bool hadStats = !m_statsClients.isEmpty();
    const bool hadStorage = !m_storageClients.isEmpty();
    if (stats) m_statsClients.insert(clientId);
    else m_statsClients.remove(clientId);
    if (storage) m_storageClients.insert(clientId);
    else m_storageClients.remove(clientId);

    if (m_statsClients.isEmpty()) {
        m_statsTimer.stop();
        m_statsPending = false;
        if (hadStats) {
            ++m_statsGeneration;
            m_statsRunning = false;
        }
    } else if (!hadStats) {
        if (m_lastStatsMs < 0 || m_clock.elapsed() - m_lastStatsMs >= statsIntervalMs) {
            m_haveCpuBaseline = false;
            if (m_cpuUsage != -1) {
                m_cpuUsage = -1;
                emit statsChanged();
            }
        }
        const auto age = m_lastStatsMs < 0 ? 0 : m_clock.elapsed() - m_lastStatsMs;
        m_statsTimer.start(int(std::max(qint64(1), statsIntervalMs - age)));
    }
    if (m_storageClients.isEmpty()) {
        m_storageTimer.stop();
        m_storagePending = false;
        if (hadStorage) {
            ++m_storageGeneration;
            m_storageRunning = false;
        }
    } else if (!hadStorage) {
        const auto age = m_lastStorageMs < 0 ? 0 : m_clock.elapsed() - m_lastStorageMs;
        m_storageTimer.start(int(std::max(qint64(1), storageIntervalMs - age)));
    }
    refresh();
}

void SystemStats::refresh() {
    const auto now = m_clock.elapsed();
    queueSample(m_lastStatsMs < 0 || now - m_lastStatsMs >= statsIntervalMs,
                m_lastStorageMs < 0 || now - m_lastStorageMs >= storageIntervalMs);
}

void SystemStats::queueSample(bool stats, bool storage) {
    m_statsPending |= stats && !m_statsClients.isEmpty() && !m_statsRunning;
    m_storagePending |= storage && !m_storageClients.isEmpty() && !m_storageRunning;
    if (m_statsPending || m_storagePending)
        m_dispatchTimer.start();
}

void SystemStats::startPendingSample() {
    if (m_running)
        return;
    const bool stats = std::exchange(m_statsPending, false) && !m_statsClients.isEmpty();
    const bool storage = std::exchange(m_storagePending, false) && !m_storageClients.isEmpty();
    if (!stats && !storage)
        return;
    m_running = true;
    m_statsRunning = stats;
    m_storageRunning = storage;
    const auto statsGeneration = m_statsGeneration;
    const auto storageGeneration = m_storageGeneration;
    auto *watcher = new QFutureWatcher<Snapshot>(this);
    connect(watcher, &QFutureWatcher<Snapshot>::finished, this,
            [this, watcher, stats, storage, statsGeneration, storageGeneration]() {
        const auto snapshot = watcher->result();
        watcher->deleteLater();
        m_running = false;
        m_statsRunning = false;
        m_storageRunning = false;
        if (stats && statsGeneration == m_statsGeneration && !m_statsClients.isEmpty()) {
            m_lastStatsMs = m_clock.elapsed();
            applyStats(snapshot);
            if (!m_statsClients.isEmpty())
                m_statsTimer.start(statsIntervalMs);
        }
        if (storage && storageGeneration == m_storageGeneration && !m_storageClients.isEmpty()) {
            m_lastStorageMs = m_clock.elapsed();
            applyStorage(snapshot);
            if (!m_storageClients.isEmpty())
                m_storageTimer.start(storageIntervalMs);
        }
        startPendingSample();
    });
    // Capture only the reader and flags: destruction never waits for I/O and
    // a late worker result cannot access the service or its CPU baseline.
    watcher->setFuture(QtConcurrent::run([reader = m_reader, stats, storage]() {
        return reader(stats, storage);
    }));
}

void SystemStats::applyStats(const Snapshot &snapshot) {
    const auto previousCpu = m_cpuUsage;
    const auto previousRam = m_ramUsage;
    const auto previousError = m_statsError;
    if (snapshot.cpuValid) {
        if (m_haveCpuBaseline && snapshot.cpuTotal > m_lastCpuTotal
            && snapshot.cpuIdle >= m_lastCpuIdle
            && snapshot.cpuIdle - m_lastCpuIdle <= snapshot.cpuTotal - m_lastCpuTotal) {
            m_cpuUsage = 1.0 - double(snapshot.cpuIdle - m_lastCpuIdle)
                / double(snapshot.cpuTotal - m_lastCpuTotal);
        } else if (!m_haveCpuBaseline || snapshot.cpuTotal < m_lastCpuTotal || snapshot.cpuIdle < m_lastCpuIdle) {
            m_cpuUsage = -1;
        }
        // No elapsed CPU ticks retains the last value instead of emitting 0%.
        m_lastCpuTotal = snapshot.cpuTotal;
        m_lastCpuIdle = snapshot.cpuIdle;
        m_haveCpuBaseline = true;
    }
    if (snapshot.ramUsage >= 0)
        m_ramUsage = std::clamp(snapshot.ramUsage, 0.0, 1.0);
    m_statsError = snapshot.statsError;
    if (previousCpu != m_cpuUsage || previousRam != m_ramUsage || previousError != m_statsError)
        emit statsChanged();
}

void SystemStats::applyStorage(const Snapshot &snapshot) {
    const auto previousUsage = m_storageUsage;
    const auto previousError = m_storageError;
    m_storageError = snapshot.storageError;
    if (snapshot.storageValid && snapshot.bytesTotal > 0
        && snapshot.bytesFree >= 0 && snapshot.bytesFree <= snapshot.bytesTotal) {
        const auto used = snapshot.bytesTotal - snapshot.bytesFree;
        // Match df: exclude reserved blocks from the denominator and round up.
        const auto denominator = static_cast<long double>(used) + snapshot.bytesAvailable;
        if (denominator > 0)
            m_storageUsage = double(std::ceil(100.0L * used / denominator));
        else
            m_storageError = QStringLiteral("Could not calculate storage usage.");
    }
    if (previousUsage != m_storageUsage || previousError != m_storageError)
        emit storageChanged();
}

SystemStats::Snapshot SystemStats::readSnapshot(bool stats, bool storage,
                                               const QString &procDirectory, const QString &storagePath) {
    Snapshot result;
    if (stats) {
        QFile cpuFile(QDir(procDirectory).filePath(QStringLiteral("stat")));
        if (!cpuFile.open(QIODevice::ReadOnly))
            result.statsError = cpuFile.errorString();
        else if (!readCpu(cpuFile.readLine(), result))
            result.statsError = QStringLiteral("Could not parse CPU stats.");
        QFile memFile(QDir(procDirectory).filePath(QStringLiteral("meminfo")));
        QString memoryError;
        if (!memFile.open(QIODevice::ReadOnly))
            memoryError = memFile.errorString();
        else if ((result.ramUsage = readRam(memFile.readAll())) < 0)
            memoryError = QStringLiteral("Could not parse memory stats.");
        if (!memoryError.isEmpty()) {
            if (!result.statsError.isEmpty()) result.statsError += u'\n';
            result.statsError += memoryError;
        }
    }
    if (storage) {
        // Construct afresh on the worker; QStorageInfo instances cache results.
        const QStorageInfo volume(storagePath);
        if (volume.isValid() && volume.isReady()) {
            result.bytesTotal = volume.bytesTotal();
            result.bytesFree = volume.bytesFree();
            result.bytesAvailable = volume.bytesAvailable();
            result.storageValid = true;
        } else {
            result.storageError = QStringLiteral("Could not read storage usage.");
        }
    }
    return result;
}
