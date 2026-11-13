#pragma once

#include <QByteArray>
#include <QHash>
#include <QLocalSocket>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QtQml/qqml.h>

class QJsonArray;
class QJsonObject;

class CompositorBackend final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString compositor READ compositor NOTIFY compositorChanged FINAL)
    Q_PROPERTY(QString focusedOutputName READ focusedOutputName NOTIFY focusedOutputNameChanged FINAL)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged FINAL)

public:
    explicit CompositorBackend(QObject *parent = nullptr);
    ~CompositorBackend() override;

    QString compositor() const;
    QString focusedOutputName() const;
    int revision() const;

    Q_INVOKABLE int activeWorkspaceIndexForOutput(const QString &outputName) const;
    Q_INVOKABLE bool isOutputFocused(const QString &outputName) const;

    bool applyNiriEventJson(const QByteArray &line);

signals:
    void compositorChanged();
    void focusedOutputNameChanged();
    void revisionChanged();

private:
    struct NiriWorkspaceState {
        quint64 id = 0;
        int index = 1;
        QString outputName;
        bool active = false;
        bool focused = false;
    };

    void detectCompositor();
    void setCompositor(const QString &compositor);
    void setFocusedOutputName(const QString &outputName);
    void bumpRevision();

#if TIDE_ISLAND_WITH_NIRI
    void startNiriEventStream();
    void connectNiriEventStream();
    void stopNiriEventStream();
    void handleNiriEventBytes();
    void handleNiriEventLine(const QByteArray &line);
    void applyNiriWorkspacesChanged(const QJsonArray &workspaces);
    void applyNiriWorkspaceActivated(const QJsonObject &event);
    bool hasNiriSocket() const;
#endif

    QString m_compositor = QStringLiteral("hyprland");
    QString m_focusedOutputName;
    int m_revision = 0;

    QHash<quint64, NiriWorkspaceState> m_niriWorkspaces;
    QHash<QString, int> m_niriActiveWorkspaceByOutput;

#if TIDE_ISLAND_WITH_NIRI
    QString m_niriSocketPath;
    QLocalSocket *m_niriEventSocket = nullptr;
    QByteArray m_niriEventBuffer;
    QTimer m_niriReconnectTimer;
#endif
};
