#include "StyleTokensBackend.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <Qt>

namespace {
QColor hex(const char *value)
{
    return QColor(QString::fromLatin1(value));
}
}

#define STYLE_COLOR(name, value) \
    QColor StyleTokensBackend::name() const \
    { \
        return token(#name, value); \
    }

#define STYLE_GLOBAL_COLOR(name, value) \
    QColor StyleTokensBackend::name() const \
    { \
        return value; \
    }

StyleTokensBackend::StyleTokensBackend(QObject *parent)
    : QObject(parent)
{
    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(120);

    connect(&m_reloadTimer, &QTimer::timeout, this, &StyleTokensBackend::reload);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &StyleTokensBackend::scheduleReload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &StyleTokensBackend::scheduleReload);

    loadFromPath(colorsPath());
    watchCurrentPath();
}

QString StyleTokensBackend::colorsPath() const
{
    QString base = qEnvironmentVariable("XDG_STATE_HOME");
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/.local/state");
    return base + QStringLiteral("/rice/tide-colors.json");
}

bool StyleTokensBackend::loadFromPath(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return false;

    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &error);
    if (error.error != QJsonParseError::NoError || !document.isObject())
        return false;

    const QJsonObject object = document.object();
    QHash<QString, QColor> tokens;
    for (auto it = object.begin(); it != object.end(); ++it) {
        if (!it.value().isString())
            continue;
        const QColor color(it.value().toString());
        if (color.isValid())
            tokens.insert(it.key(), color);
    }

    m_tokens = tokens;
    emit changed();
    return true;
}

QColor StyleTokensBackend::token(const char *name, const char *fallback) const
{
    const auto it = m_tokens.constFind(QString::fromLatin1(name));
    if (it != m_tokens.constEnd())
        return it.value();
    return hex(fallback);
}

void StyleTokensBackend::reload()
{
    loadFromPath(colorsPath());
    watchCurrentPath();
}

void StyleTokensBackend::scheduleReload()
{
    m_reloadTimer.start();
}

void StyleTokensBackend::watchCurrentPath()
{
    const QString path = colorsPath();
    if (!m_watcher.files().contains(path) && QFile::exists(path))
        m_watcher.addPath(path);

    const QString directory = QFileInfo(path).absolutePath();
    if (!m_watcher.directories().contains(directory) && QDir(directory).exists())
        m_watcher.addPath(directory);
}

STYLE_GLOBAL_COLOR(transparent, Qt::transparent)
STYLE_GLOBAL_COLOR(black, Qt::black)
STYLE_GLOBAL_COLOR(white, Qt::white)
QColor StyleTokensBackend::clearBlack() const { return QColor(0, 0, 0, 0); }
STYLE_COLOR(panel, "#202125")
STYLE_COLOR(surfaceBorder, "#26ffffff")
STYLE_COLOR(surfaceHighlight, "#0cffffff")
STYLE_COLOR(module, "#303136")
STYLE_COLOR(moduleHover, "#3a3b40")
STYLE_COLOR(track, "#242529")
STYLE_COLOR(cardFillActive, "#26272b")
STYLE_COLOR(cardFillHover, "#222327")
STYLE_COLOR(connectivityCard, "#343437")
STYLE_COLOR(connectivityCardHover, "#3a3a3d")
STYLE_COLOR(prompt, "#323236")
STYLE_COLOR(input, "#212226")
STYLE_COLOR(inputBorder, "#3f4046")
STYLE_COLOR(secondaryButton, "#4a4b50")
STYLE_COLOR(textPrimary, "#f5f5f7")
STYLE_COLOR(textPrimaryBright, "#f7f8fb")
STYLE_COLOR(textSecondary, "#b6b6bf")
STYLE_COLOR(textMuted, "#acadb6")
STYLE_COLOR(textSoft, "#9da0a8")
STYLE_COLOR(textTertiary, "#7f828a")
STYLE_COLOR(textDisabled, "#878a92")
STYLE_COLOR(textSubtle, "#8f9198")
STYLE_COLOR(textDim, "#b5b7bf")
STYLE_COLOR(accent, "#0a84ff")
STYLE_COLOR(accentPressed, "#0066d6")
STYLE_COLOR(accentSoft, "#6ea8ff")
STYLE_COLOR(success, "#34c759")
STYLE_COLOR(warning, "#ffcc00")
STYLE_COLOR(danger, "#ff3b30")
STYLE_COLOR(error, "#ff7c72")
STYLE_COLOR(disabledControl, "#868991")
STYLE_COLOR(switchOff, "#63656c")
STYLE_COLOR(buttonFill, "#f5f5f7")
STYLE_COLOR(buttonFillHover, "#f5f5f7")
STYLE_COLOR(buttonFillPressed, "#e9e9ec")
STYLE_COLOR(overviewCard, "#ee17181b")
STYLE_COLOR(overviewBorder, "#33ffffff")
STYLE_COLOR(overviewInnerBorder, "#12ffffff")
STYLE_COLOR(workspaceCell, "#ff202226")
STYLE_COLOR(workspaceCellHover, "#ff2b2d34")
STYLE_COLOR(workspaceCellBorder, "#1effffff")
STYLE_COLOR(workspaceCellBorderHover, "#66d9f6ff")
STYLE_COLOR(workspaceOverlay, "#42070b10")
STYLE_COLOR(workspaceOverlayHover, "#280d131a")
STYLE_COLOR(workspaceActiveBorder, "#73d4ff")

int StyleTokensBackend::radiusPanel() const { return 28; }
int StyleTokensBackend::radiusModule() const { return 20; }
int StyleTokensBackend::radiusPrompt() const { return 16; }
int StyleTokensBackend::radiusButton() const { return 12; }
int StyleTokensBackend::durationFast() const { return 120; }
int StyleTokensBackend::durationControl() const { return 130; }
int StyleTokensBackend::durationQuick() const { return 140; }
int StyleTokensBackend::durationStandard() const { return 240; }

#undef STYLE_COLOR
#undef STYLE_GLOBAL_COLOR
