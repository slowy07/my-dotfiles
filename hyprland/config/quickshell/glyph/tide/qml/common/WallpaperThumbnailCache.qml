import QtCore
import QtQuick
import Quickshell.Io
import IslandBackend

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string sourcePath: ""
    property int targetWidth: 960
    property int targetHeight: 540
    property int quality: 86
    property int refreshDebounceInterval: 140
    property int retryBackoffInterval: 1500
    property int maxFailureRetries: 2

    readonly property string normalizedSourcePath: localPath(sourcePath)
    readonly property string cacheDir: localPath(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation))
        + "/quickshell/dynamic_island/workspace-overview"
    readonly property string cacheFileName: "wallpaper-"
        + hashString(normalizedSourcePath + "|" + targetWidth + "x" + targetHeight)
        + ".jpg"
    readonly property string cacheRelativePath: "quickshell/dynamic_island/workspace-overview/" + cacheFileName
    readonly property string cachePath: cacheDir + "/" + cacheFileName
    readonly property string effectiveSource: cacheAvailable
        ? (toFileUrl(cachePath) + "?v=" + cacheRevision)
        : (normalizedSourcePath === "" ? "" : (toFileUrl(normalizedSourcePath) + "?v=source-" + sourceRevision))

    property bool cacheAvailable: false
    property int cacheRevision: 0
    property bool refreshPending: false
    property bool thumbnailRequestActive: false
    property string inFlightCachePath: ""
    property string inFlightSourcePath: ""
    property int consecutiveFailureCount: 0
    property int sourceRevision: 0
    readonly property bool busy: refreshPending || refreshDebounceTimer.running || thumbnailRequestActive

    function localPath(value) {
        if (value === undefined || value === null)
            return "";
        if (value.toLocalFile)
            return value.toLocalFile();

        const text = String(value);
        return text.startsWith("file://") ? text.substring(7) : text;
    }

    function toFileUrl(localFile) {
        return localFile === "" ? "" : ("file://" + encodeURI(localFile));
    }

    function hashString(value) {
        let hash = 2166136261;
        const text = String(value || "");

        for (let index = 0; index < text.length; index++) {
            hash ^= text.charCodeAt(index);
            hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24);
        }

        return (hash >>> 0).toString(16);
    }

    function hasCacheOnDisk() {
        return localPath(StandardPaths.locate(StandardPaths.GenericCacheLocation, cacheRelativePath)) !== "";
    }

    function scheduleRefresh() {
        consecutiveFailureCount = 0;
        refreshPending = true;
        refreshDebounceTimer.interval = refreshDebounceInterval;
        refreshDebounceTimer.restart();
    }

    function refreshNow() {
        consecutiveFailureCount = 0;
        refreshPending = true;
        refreshDebounceTimer.interval = refreshDebounceInterval;
        refreshDebounceTimer.stop();
        refreshCache();
    }

    function refreshCache() {
        if (!refreshPending || thumbnailRequestActive)
            return;

        refreshPending = false;

        if (normalizedSourcePath === "")
            return;

        inFlightCachePath = cachePath;
        inFlightSourcePath = normalizedSourcePath;
        thumbnailRequestActive = true;
        SystemServices.generateWallpaperThumbnail(
            normalizedSourcePath,
            cachePath,
            cacheDir,
            targetWidth,
            targetHeight,
            quality
        );
    }

    onCachePathChanged: {
        cacheAvailable = hasCacheOnDisk();
        sourceRevision += 1;
        scheduleRefresh();
    }

    Component.onCompleted: {
        cacheAvailable = hasCacheOnDisk();
        scheduleRefresh();
    }
    Component.onDestruction: {
        refreshDebounceTimer.stop();
        refreshPending = false;
    }

    Timer {
        id: refreshDebounceTimer

        interval: root.refreshDebounceInterval
        repeat: false

        onTriggered: root.refreshCache()
    }

    FileView {
        id: sourceWatcher

        path: root.normalizedSourcePath
        watchChanges: true
        preload: false
        printErrors: false

        onFileChanged: {
            root.sourceRevision += 1;
            root.cacheAvailable = false;
            root.scheduleRefresh();
        }
    }

    Connections {
        target: SystemServices

        function onWallpaperThumbnailFinished(sourcePath, finishedCachePath, cacheAvailable, updated, errorString) {
            if (finishedCachePath !== root.inFlightCachePath || sourcePath !== root.inFlightSourcePath)
                return;

            root.thumbnailRequestActive = false;

            const targetStillCurrent = root.inFlightCachePath === root.cachePath
                && root.inFlightSourcePath === root.normalizedSourcePath;

            if (targetStillCurrent) {
                root.cacheAvailable = cacheAvailable || root.hasCacheOnDisk();
                if (errorString === "") {
                    root.consecutiveFailureCount = 0;
                    refreshDebounceTimer.interval = root.refreshDebounceInterval;
                } else {
                    root.consecutiveFailureCount += 1;
                }

                if (errorString === ""
                        && root.cacheAvailable
                        && updated) {
                    root.cacheRevision += 1;
                }
            }

            if (!targetStillCurrent) {
                root.consecutiveFailureCount = 0;
                refreshDebounceTimer.interval = root.refreshDebounceInterval;
                refreshDebounceTimer.restart();
                return;
            }

            if (root.refreshPending) {
                if (root.consecutiveFailureCount <= root.maxFailureRetries) {
                    refreshDebounceTimer.interval = root.consecutiveFailureCount > 0
                        ? root.retryBackoffInterval
                        : root.refreshDebounceInterval;
                    refreshDebounceTimer.restart();
                } else {
                    root.refreshPending = false;
                    refreshDebounceTimer.stop();
                    refreshDebounceTimer.interval = root.refreshDebounceInterval;
                }
            }
        }
    }
}
