#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqml.h>

class UserConfigBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(UserConfig)
    QML_SINGLETON

    Q_PROPERTY(QString userConfigPath READ userConfigPath CONSTANT FINAL)
    Q_PROPERTY(QVariantMap lockScreen READ lockScreen NOTIFY lockScreenChanged FINAL)
    Q_PROPERTY(QString configError READ configError NOTIFY configErrorChanged FINAL)
    Q_PROPERTY(QString defaultWallpaperPath READ defaultWallpaperPath WRITE setDefaultWallpaperPath NOTIFY defaultWallpaperPathChanged FINAL)
    Q_PROPERTY(QString defaultTlpSudoPassword READ defaultTlpSudoPassword WRITE setDefaultTlpSudoPassword NOTIFY defaultTlpSudoPasswordChanged FINAL)

    Q_PROPERTY(QString wallpaperPath READ wallpaperPath NOTIFY wallpaperPathChanged FINAL)
    Q_PROPERTY(QString wallpaperLibraryPath READ wallpaperLibraryPath NOTIFY wallpaperLibraryPathChanged FINAL)
    Q_PROPERTY(bool wallpaperPywalEnabled READ wallpaperPywalEnabled NOTIFY wallpaperPywalEnabledChanged FINAL)
    Q_PROPERTY(bool wallpaperCustomCommandEnabled READ wallpaperCustomCommandEnabled NOTIFY wallpaperCustomCommandEnabledChanged FINAL)
    Q_PROPERTY(QString wallpaperCustomCommand READ wallpaperCustomCommand NOTIFY wallpaperCustomCommandChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionType READ wallpaperTransitionType NOTIFY wallpaperTransitionTypeChanged FINAL)
    Q_PROPERTY(int wallpaperTransitionStep READ wallpaperTransitionStep NOTIFY wallpaperTransitionStepChanged FINAL)
    Q_PROPERTY(double wallpaperTransitionDuration READ wallpaperTransitionDuration NOTIFY wallpaperTransitionDurationChanged FINAL)
    Q_PROPERTY(int wallpaperTransitionFps READ wallpaperTransitionFps NOTIFY wallpaperTransitionFpsChanged FINAL)
    Q_PROPERTY(int wallpaperTransitionAngle READ wallpaperTransitionAngle NOTIFY wallpaperTransitionAngleChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionPosition READ wallpaperTransitionPosition NOTIFY wallpaperTransitionPositionChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionBezier READ wallpaperTransitionBezier NOTIFY wallpaperTransitionBezierChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionWave READ wallpaperTransitionWave NOTIFY wallpaperTransitionWaveChanged FINAL)
    Q_PROPERTY(bool wallpaperTransitionInvertY READ wallpaperTransitionInvertY NOTIFY wallpaperTransitionInvertYChanged FINAL)
    Q_PROPERTY(QString iconFontFamily READ iconFontFamily NOTIFY iconFontFamilyChanged FINAL)
    Q_PROPERTY(QString textFontFamily READ textFontFamily NOTIFY textFontFamilyChanged FINAL)
    Q_PROPERTY(QString heroFontFamily READ heroFontFamily NOTIFY heroFontFamilyChanged FINAL)
    Q_PROPERTY(QString timeFontFamily READ timeFontFamily NOTIFY timeFontFamilyChanged FINAL)
    Q_PROPERTY(QString clockFormat READ clockFormat NOTIFY clockFormatChanged FINAL)
    Q_PROPERTY(QString tlpSudoPassword READ tlpSudoPassword NOTIFY tlpSudoPasswordChanged FINAL)
    Q_PROPERTY(QString tlpPermissionMode READ tlpPermissionMode NOTIFY tlpPermissionModeChanged FINAL)
    Q_PROPERTY(QString powerProfileDriver READ powerProfileDriver NOTIFY powerProfileDriverChanged FINAL)

    Q_PROPERTY(int workspaceOverviewWindowDragButton READ workspaceOverviewWindowDragButton NOTIFY workspaceOverviewWindowDragButtonChanged FINAL)

    Q_PROPERTY(int dynamicIslandPrimaryButton READ dynamicIslandPrimaryButton NOTIFY dynamicIslandPrimaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandPrimaryAction READ dynamicIslandPrimaryAction NOTIFY dynamicIslandPrimaryActionChanged FINAL)
    Q_PROPERTY(int dynamicIslandSecondaryButton READ dynamicIslandSecondaryButton NOTIFY dynamicIslandSecondaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandSecondaryAction READ dynamicIslandSecondaryAction NOTIFY dynamicIslandSecondaryActionChanged FINAL)
    Q_PROPERTY(int dynamicIslandMiddleButton READ dynamicIslandMiddleButton NOTIFY dynamicIslandMiddleButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandMiddleAction READ dynamicIslandMiddleAction NOTIFY dynamicIslandMiddleActionChanged FINAL)
    Q_PROPERTY(QVariantList dynamicIslandLeftSwipeItems READ dynamicIslandLeftSwipeItems NOTIFY dynamicIslandLeftSwipeItemsChanged FINAL)
    Q_PROPERTY(bool disableAutoExpandOnTrackChange READ disableAutoExpandOnTrackChange NOTIFY disableAutoExpandOnTrackChangeChanged FINAL)
    Q_PROPERTY(int hoverExpandAction READ hoverExpandAction NOTIFY hoverExpandActionChanged FINAL)
    Q_PROPERTY(bool islandAutoHideEnabled READ islandAutoHideEnabled NOTIFY islandAutoHideEnabledChanged FINAL)
    Q_PROPERTY(int islandAutoHideDelayMs READ islandAutoHideDelayMs NOTIFY islandAutoHideDelayMsChanged FINAL)
    Q_PROPERTY(bool islandShowWorkspaceOnAutoHide READ islandShowWorkspaceOnAutoHide NOTIFY islandShowWorkspaceOnAutoHideChanged FINAL)

    Q_PROPERTY(int islandWidth READ islandWidth NOTIFY islandWidthChanged FINAL)
    Q_PROPERTY(int islandHeight READ islandHeight NOTIFY islandHeightChanged FINAL)
    Q_PROPERTY(int islandExclusiveZone READ islandExclusiveZone NOTIFY islandExclusiveZoneChanged FINAL)
    Q_PROPERTY(int islandTopMargin READ islandTopMargin NOTIFY islandTopMarginChanged FINAL)
    Q_PROPERTY(int islandPositionX READ islandPositionX NOTIFY islandPositionXChanged FINAL)
    Q_PROPERTY(int islandBackgroundOpacity READ islandBackgroundOpacity NOTIFY islandBackgroundOpacityChanged FINAL)
    Q_PROPERTY(bool islandBlurEnabled READ islandBlurEnabled NOTIFY islandBlurEnabledChanged FINAL)
    Q_PROPERTY(int bodyFontSize READ bodyFontSize NOTIFY bodyFontSizeChanged FINAL)
    Q_PROPERTY(int titleFontSize READ titleFontSize NOTIFY titleFontSizeChanged FINAL)
    Q_PROPERTY(int iconFontSize READ iconFontSize NOTIFY iconFontSizeChanged FINAL)

    Q_PROPERTY(bool weatherEnabled READ weatherEnabled NOTIFY weatherEnabledChanged FINAL)
    Q_PROPERTY(QString weatherLocation READ weatherLocation NOTIFY weatherLocationChanged FINAL)
    Q_PROPERTY(QString weatherUnits READ weatherUnits NOTIFY weatherUnitsChanged FINAL)
    Q_PROPERTY(int weatherRefreshInterval READ weatherRefreshInterval NOTIFY weatherRefreshIntervalChanged FINAL)

public:
    explicit UserConfigBackend(QObject *parent = nullptr);
    QVariantMap lockScreen() const { return m_lockScreen; }

    QString userConfigPath() const;
    QString configError() const;
    QString defaultWallpaperPath() const;
    QString defaultTlpSudoPassword() const;
    QString wallpaperPath() const;
    QString wallpaperLibraryPath() const;
    bool wallpaperPywalEnabled() const;
    bool wallpaperCustomCommandEnabled() const;
    QString wallpaperCustomCommand() const;
    QString wallpaperTransitionType() const;
    int wallpaperTransitionStep() const;
    double wallpaperTransitionDuration() const;
    int wallpaperTransitionFps() const;
    int wallpaperTransitionAngle() const;
    QString wallpaperTransitionPosition() const;
    QString wallpaperTransitionBezier() const;
    QString wallpaperTransitionWave() const;
    bool wallpaperTransitionInvertY() const;
    QString iconFontFamily() const;
    QString textFontFamily() const;
    QString heroFontFamily() const;
    QString timeFontFamily() const;
    QString clockFormat() const;
    QString tlpSudoPassword() const;
    QString tlpPermissionMode() const;
    QString powerProfileDriver() const;
    int workspaceOverviewWindowDragButton() const;
    int dynamicIslandPrimaryButton() const;
    QString dynamicIslandPrimaryAction() const;
    int dynamicIslandSecondaryButton() const;
    QString dynamicIslandSecondaryAction() const;
    int dynamicIslandMiddleButton() const;
    QString dynamicIslandMiddleAction() const;
    const QVariantList &dynamicIslandLeftSwipeItems() const;
    bool disableAutoExpandOnTrackChange() const;
    int hoverExpandAction() const;
    bool islandShowWorkspaceOnAutoHide() const;
    bool islandAutoHideEnabled() const;
    int islandAutoHideDelayMs() const;
    int islandWidth() const;
    int islandHeight() const;
    int islandExclusiveZone() const;
    int islandTopMargin() const;
    int islandPositionX() const;
    int islandBackgroundOpacity() const;
    bool islandBlurEnabled() const;
    int bodyFontSize() const;
    int titleFontSize() const;
    int iconFontSize() const;
    bool weatherEnabled() const;
    QString weatherLocation() const;
    QString weatherUnits() const;
    int weatherRefreshInterval() const;
    void setDefaultWallpaperPath(const QString &path);
    void setDefaultTlpSudoPassword(const QString &password);

    Q_INVOKABLE int mouseButton(const QVariant &button) const;
    Q_INVOKABLE int mouseButtonsMask(const QVariant &buttons) const;
    Q_INVOKABLE void reload();

signals:
    void lockScreenChanged();
    void configErrorChanged();
    void defaultWallpaperPathChanged();
    void defaultTlpSudoPasswordChanged();
    void wallpaperPathChanged();
    void wallpaperLibraryPathChanged();
    void wallpaperPywalEnabledChanged();
    void wallpaperCustomCommandEnabledChanged();
    void wallpaperCustomCommandChanged();
    void wallpaperTransitionTypeChanged();
    void wallpaperTransitionStepChanged();
    void wallpaperTransitionDurationChanged();
    void wallpaperTransitionFpsChanged();
    void wallpaperTransitionAngleChanged();
    void wallpaperTransitionPositionChanged();
    void wallpaperTransitionBezierChanged();
    void wallpaperTransitionWaveChanged();
    void wallpaperTransitionInvertYChanged();
    void iconFontFamilyChanged();
    void textFontFamilyChanged();
    void heroFontFamilyChanged();
    void timeFontFamilyChanged();
    void clockFormatChanged();
    void tlpSudoPasswordChanged();
    void tlpPermissionModeChanged();
    void powerProfileDriverChanged();
    void workspaceOverviewWindowDragButtonChanged();
    void dynamicIslandPrimaryButtonChanged();
    void dynamicIslandPrimaryActionChanged();
    void dynamicIslandSecondaryButtonChanged();
    void dynamicIslandSecondaryActionChanged();
    void dynamicIslandMiddleButtonChanged();
    void dynamicIslandMiddleActionChanged();
    void dynamicIslandLeftSwipeItemsChanged();
    void disableAutoExpandOnTrackChangeChanged();
    void islandShowWorkspaceOnAutoHideChanged();
    void hoverExpandActionChanged();
    void islandAutoHideEnabledChanged();
    void islandAutoHideDelayMsChanged();
    void islandWidthChanged();
    void islandHeightChanged();
    void islandExclusiveZoneChanged();
    void islandTopMarginChanged();
    void islandPositionXChanged();
    void islandBackgroundOpacityChanged();
    void islandBlurEnabledChanged();
    void bodyFontSizeChanged();
    void titleFontSizeChanged();
    void iconFontSizeChanged();
    void weatherEnabledChanged();
    void weatherLocationChanged();
    void weatherUnitsChanged();
    void weatherRefreshIntervalChanged();

private:
    QVariantMap m_lockScreen;
    void scheduleReload();
    void loadConfig();
    void updateWatchedPaths();
    QString configHome() const;

    QString m_userConfigPath;
    QString m_configError;
    QString m_defaultWallpaperPath;
    QString m_defaultTlpSudoPassword;
    QString m_wallpaperPath;
    QString m_wallpaperLibraryPath;
    bool m_wallpaperPywalEnabled = false;
    bool m_wallpaperCustomCommandEnabled = false;
    QString m_wallpaperCustomCommand;
    QString m_wallpaperTransitionType = QStringLiteral("center");
    int m_wallpaperTransitionStep = 5;
    double m_wallpaperTransitionDuration = 3.0;
    int m_wallpaperTransitionFps = 60;
    int m_wallpaperTransitionAngle = 45;
    QString m_wallpaperTransitionPosition = QStringLiteral("center");
    QString m_wallpaperTransitionBezier = QStringLiteral(".54,0,.34,.99");
    QString m_wallpaperTransitionWave = QStringLiteral("20,20");
    bool m_wallpaperTransitionInvertY = false;
    QString m_iconFontFamily = QStringLiteral("JetBrainsMono Nerd Font");
    QString m_textFontFamily = QStringLiteral("Sans Serif");
    QString m_heroFontFamily = QStringLiteral("Sans Serif");
    QString m_timeFontFamily = QStringLiteral("Sans Serif");
    QString m_clockFormat = QStringLiteral("12");
    QString m_tlpSudoPassword;
    QString m_tlpPermissionMode = QStringLiteral("skip");
    QString m_powerProfileDriver = QStringLiteral("auto");
    int m_workspaceOverviewWindowDragButton = 1;
    int m_dynamicIslandPrimaryButton = 1;
    QString m_dynamicIslandPrimaryAction = QStringLiteral("toggleExpandedPlayer");
    int m_dynamicIslandSecondaryButton = 3;
    QString m_dynamicIslandSecondaryAction = QStringLiteral("toggleControlCenter");
    int m_dynamicIslandMiddleButton = 2;
    QString m_dynamicIslandMiddleAction = QStringLiteral("toggleClipboard");
    QVariantList m_dynamicIslandLeftSwipeItems;
    bool m_islandShowWorkspaceOnAutoHide = true;
    bool m_disableAutoExpandOnTrackChange = false;
    int m_hoverExpandAction = 1;
    bool m_islandAutoHideEnabled = true;
    int m_islandAutoHideDelayMs = 1000;
    int m_islandWidth = 140;
    int m_islandBackgroundOpacity = 60;
    bool m_islandBlurEnabled = true;
    int m_islandHeight = 38;
    int m_islandExclusiveZone = 45;
    int m_islandTopMargin = 4;
    int m_islandPositionX = 50;
    int m_bodyFontSize = 16;
    int m_titleFontSize = 20;
    int m_iconFontSize = 18;
    bool m_weatherEnabled = true;
    QString m_weatherLocation;
    QString m_weatherUnits = QStringLiteral("metric");
    int m_weatherRefreshInterval = 1800000;

    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
