#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QHash>
#include <QObject>
#include <QTimer>
#include <QtQml/qqml.h>

class StyleTokensBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(StyleTokens)
    QML_SINGLETON

    Q_PROPERTY(QColor transparent READ transparent CONSTANT FINAL)
    Q_PROPERTY(QColor black READ black CONSTANT FINAL)
    Q_PROPERTY(QColor white READ white CONSTANT FINAL)
    Q_PROPERTY(QColor clearBlack READ clearBlack CONSTANT FINAL)

    Q_PROPERTY(QColor panel READ panel NOTIFY changed FINAL)
    Q_PROPERTY(QColor surfaceBorder READ surfaceBorder NOTIFY changed FINAL)
    Q_PROPERTY(QColor surfaceHighlight READ surfaceHighlight NOTIFY changed FINAL)
    Q_PROPERTY(QColor module READ module NOTIFY changed FINAL)
    Q_PROPERTY(QColor moduleHover READ moduleHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor track READ track NOTIFY changed FINAL)
    Q_PROPERTY(QColor cardFillActive READ cardFillActive NOTIFY changed FINAL)
    Q_PROPERTY(QColor cardFillHover READ cardFillHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor connectivityCard READ connectivityCard NOTIFY changed FINAL)
    Q_PROPERTY(QColor connectivityCardHover READ connectivityCardHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor prompt READ prompt NOTIFY changed FINAL)
    Q_PROPERTY(QColor input READ input NOTIFY changed FINAL)
    Q_PROPERTY(QColor inputBorder READ inputBorder NOTIFY changed FINAL)
    Q_PROPERTY(QColor secondaryButton READ secondaryButton NOTIFY changed FINAL)

    Q_PROPERTY(QColor textPrimary READ textPrimary NOTIFY changed FINAL)
    Q_PROPERTY(QColor textPrimaryBright READ textPrimaryBright NOTIFY changed FINAL)
    Q_PROPERTY(QColor textSecondary READ textSecondary NOTIFY changed FINAL)
    Q_PROPERTY(QColor textMuted READ textMuted NOTIFY changed FINAL)
    Q_PROPERTY(QColor textSoft READ textSoft NOTIFY changed FINAL)
    Q_PROPERTY(QColor textTertiary READ textTertiary NOTIFY changed FINAL)
    Q_PROPERTY(QColor textDisabled READ textDisabled NOTIFY changed FINAL)
    Q_PROPERTY(QColor textSubtle READ textSubtle NOTIFY changed FINAL)
    Q_PROPERTY(QColor textDim READ textDim NOTIFY changed FINAL)

    Q_PROPERTY(QColor accent READ accent NOTIFY changed FINAL)
    Q_PROPERTY(QColor accentPressed READ accentPressed NOTIFY changed FINAL)
    Q_PROPERTY(QColor accentSoft READ accentSoft NOTIFY changed FINAL)
    Q_PROPERTY(QColor success READ success NOTIFY changed FINAL)
    Q_PROPERTY(QColor warning READ warning NOTIFY changed FINAL)
    Q_PROPERTY(QColor danger READ danger NOTIFY changed FINAL)
    Q_PROPERTY(QColor error READ error NOTIFY changed FINAL)
    Q_PROPERTY(QColor disabledControl READ disabledControl NOTIFY changed FINAL)
    Q_PROPERTY(QColor switchOff READ switchOff NOTIFY changed FINAL)

    Q_PROPERTY(QColor buttonFill READ buttonFill NOTIFY changed FINAL)
    Q_PROPERTY(QColor buttonFillHover READ buttonFillHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor buttonFillPressed READ buttonFillPressed NOTIFY changed FINAL)

    Q_PROPERTY(QColor overviewCard READ overviewCard NOTIFY changed FINAL)
    Q_PROPERTY(QColor overviewBorder READ overviewBorder NOTIFY changed FINAL)
    Q_PROPERTY(QColor overviewInnerBorder READ overviewInnerBorder NOTIFY changed FINAL)
    Q_PROPERTY(QColor workspaceCell READ workspaceCell NOTIFY changed FINAL)
    Q_PROPERTY(QColor workspaceCellHover READ workspaceCellHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor workspaceCellBorder READ workspaceCellBorder NOTIFY changed FINAL)
    Q_PROPERTY(QColor workspaceCellBorderHover READ workspaceCellBorderHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor workspaceOverlay READ workspaceOverlay NOTIFY changed FINAL)
    Q_PROPERTY(QColor workspaceOverlayHover READ workspaceOverlayHover NOTIFY changed FINAL)
    Q_PROPERTY(QColor workspaceActiveBorder READ workspaceActiveBorder NOTIFY changed FINAL)

    Q_PROPERTY(int radiusPanel READ radiusPanel CONSTANT FINAL)
    Q_PROPERTY(int radiusModule READ radiusModule CONSTANT FINAL)
    Q_PROPERTY(int radiusPrompt READ radiusPrompt CONSTANT FINAL)
    Q_PROPERTY(int radiusButton READ radiusButton CONSTANT FINAL)
    Q_PROPERTY(int durationFast READ durationFast CONSTANT FINAL)
    Q_PROPERTY(int durationControl READ durationControl CONSTANT FINAL)
    Q_PROPERTY(int durationQuick READ durationQuick CONSTANT FINAL)
    Q_PROPERTY(int durationStandard READ durationStandard CONSTANT FINAL)

public:
    explicit StyleTokensBackend(QObject *parent = nullptr);

    QColor transparent() const;
    QColor black() const;
    QColor white() const;
    QColor clearBlack() const;
    QColor panel() const;
    QColor surfaceBorder() const;
    QColor surfaceHighlight() const;
    QColor module() const;
    QColor moduleHover() const;
    QColor track() const;
    QColor cardFillActive() const;
    QColor cardFillHover() const;
    QColor connectivityCard() const;
    QColor connectivityCardHover() const;
    QColor prompt() const;
    QColor input() const;
    QColor inputBorder() const;
    QColor secondaryButton() const;
    QColor textPrimary() const;
    QColor textPrimaryBright() const;
    QColor textSecondary() const;
    QColor textMuted() const;
    QColor textSoft() const;
    QColor textTertiary() const;
    QColor textDisabled() const;
    QColor textSubtle() const;
    QColor textDim() const;
    QColor accent() const;
    QColor accentPressed() const;
    QColor accentSoft() const;
    QColor success() const;
    QColor warning() const;
    QColor danger() const;
    QColor error() const;
    QColor disabledControl() const;
    QColor switchOff() const;
    QColor buttonFill() const;
    QColor buttonFillHover() const;
    QColor buttonFillPressed() const;
    QColor overviewCard() const;
    QColor overviewBorder() const;
    QColor overviewInnerBorder() const;
    QColor workspaceCell() const;
    QColor workspaceCellHover() const;
    QColor workspaceCellBorder() const;
    QColor workspaceCellBorderHover() const;
    QColor workspaceOverlay() const;
    QColor workspaceOverlayHover() const;
    QColor workspaceActiveBorder() const;

    int radiusPanel() const;
    int radiusModule() const;
    int radiusPrompt() const;
    int radiusButton() const;
    int durationFast() const;
    int durationControl() const;
    int durationQuick() const;
    int durationStandard() const;

    bool loadFromPath(const QString &path);

signals:
    void changed();

private:
    QColor token(const char *name, const char *fallback) const;
    QString colorsPath() const;
    void reload();
    void scheduleReload();
    void watchCurrentPath();

    QHash<QString, QColor> m_tokens;
    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
