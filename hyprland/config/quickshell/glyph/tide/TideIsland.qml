import QtQuick
import Quickshell
import IslandBackend
import qs

// Glyph controller for the vendored Tide island. Replaces upstream shell.qml.
// Only clock, player, calendar and notification center are reachable; the
// overview, lyrics, clipboard and lock screen hooks are inert.
Scope {
    id: root

    readonly property bool screenRecordingActive: false
    readonly property var userConfig: UserConfig
    readonly property var weatherService: null
    property bool focusEnabled: false
    property bool nightLightEnabled: false
    property bool islandAutoHideRuntimeEnabled: false
    readonly property string clockFormat: Theme.state.clock24 ? "24" : "12"

    // one history for every screen; the window reads it from here
    readonly property var notificationHistoryModel: history
    ListModel { id: history }

    function forEachWindow(callback) {
        const windows = panelVariants.instances ? panelVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            if (windows[index])
                callback(windows[index]);
        }
    }

    function forFocusedWindow(callback) {
        let fallback = null;
        let found = null;
        forEachWindow(window => {
            if (!fallback)
                fallback = window;
            if (!found && window.monitorFocused)
                found = window;
        });
        if (found)
            callback(found);
        else if (fallback)
            callback(fallback);
    }

    function recordNotification(appName, summary, body) {
        history.insert(0, {
            appName: appName !== "" ? appName : "Notification",
            summary: summary !== "" ? summary : (body !== "" ? body : "New notification"),
            body: body,
            timestamp: new Date()
        });
        if (history.count > 50)
            history.remove(50, history.count - 50);
    }

    function showNotificationAll(appName, summary, body) {
        recordNotification(appName, summary, body);
        if (Theme.state.dnd)
            return;
        forFocusedWindow(window => window.showNotification(appName, summary, body));
    }

    // power, network and focus events show the capsule without entering the
    // notification history, per the Glyph controller contract. DND does not
    // suppress them: the top edge flash already ignores DND and these are
    // system events the user wants to see.
    function showTransient(appName, summary, body) {
        forFocusedWindow(window => window.showNotification(appName, summary, body));
    }

    // the dormant upstream layers call these; they stay no-ops here
    function lockScreen() {}
    function anyOverviewOpen() { return false; }
    function prepareOverviewAll() {}
    function cancelPreparedOverviewAll() {}
    function openOverviewAll() {}
    function closeOverviewAll() {}
    function toggleOverviewAll() {}
    function refreshOverviewWallpaperCaches() {}

    Connections {
        target: Notes
        function onReceived(n) {
            root.showNotificationAll(n.appName ?? "", n.summary ?? "", n.body ?? "");
        }
    }

    Variants {
        id: panelVariants
        model: Quickshell.screens

        DynamicIslandWindow {
            required property var modelData
            screen: modelData
            shellRootController: root
        }
    }
}
