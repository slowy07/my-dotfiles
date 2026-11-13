import QtQuick
import Quickshell
import Quickshell.Hyprland
import IslandBackend

Item {
    id: root

    visible: false

    property var windowList: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var activeWorkspace: null
    property var monitors: []
    property bool clientsReady: false
    property bool monitorsReady: false
    property bool workspacesReady: false
    property bool activeWorkspaceReady: false
    property bool clientsRefreshPending: false
    property bool monitorsRefreshPending: false
    property bool workspacesRefreshPending: false
    property bool activeWorkspaceRefreshPending: false
    property bool clientsRequestRunning: false
    property bool monitorsRequestRunning: false
    property bool workspacesRequestRunning: false
    property bool activeWorkspaceRequestRunning: false
    readonly property bool ready: clientsReady && monitorsReady && workspacesReady && activeWorkspaceReady

    function parseJson(text, fallback) {
        const source = String(text === undefined || text === null ? "" : text).trim();
        if (source === "")
            return fallback;

        try {
            return JSON.parse(source);
        } catch (error) {
            console.log("[HyprlandData] Failed to parse snapshot:", error);
            return fallback;
        }
    }

    function rebuildWindowIndex() {
        const byAddress = {};
        for (let index = 0; index < root.windowList.length; index++)
            byAddress[String(root.windowList[index].address || "").toLowerCase()] = root.windowList[index];
        root.windowByAddress = byAddress;
    }

    function requestRefresh(refreshClients, refreshMonitors, refreshWorkspaces, refreshActiveWorkspace, immediate) {
        clientsRefreshPending = clientsRefreshPending || refreshClients;
        monitorsRefreshPending = monitorsRefreshPending || refreshMonitors;
        workspacesRefreshPending = workspacesRefreshPending || refreshWorkspaces;
        activeWorkspaceRefreshPending = activeWorkspaceRefreshPending || refreshActiveWorkspace;

        if (immediate) {
            refreshTimer.stop();
            flushRefresh();
        } else {
            refreshTimer.restart();
        }
    }

    function queueRefresh(refreshClients, refreshMonitors, refreshWorkspaces, refreshActiveWorkspace) {
        requestRefresh(refreshClients, refreshMonitors, refreshWorkspaces, refreshActiveWorkspace, false);
    }

    function updateAll() {
        requestRefresh(true, true, true, true, true);
    }

    function flushRefresh() {
        if (clientsRefreshPending && !clientsRequestRunning) {
            clientsRefreshPending = false;
            clientsRequestRunning = true;
            SystemServices.requestHyprlandSnapshot("clients", "clients");
        }
        if (monitorsRefreshPending && !monitorsRequestRunning) {
            monitorsRefreshPending = false;
            monitorsRequestRunning = true;
            SystemServices.requestHyprlandSnapshot("monitors", "monitors");
        }
        if (workspacesRefreshPending && !workspacesRequestRunning) {
            workspacesRefreshPending = false;
            workspacesRequestRunning = true;
            SystemServices.requestHyprlandSnapshot("workspaces", "workspaces");
        }
        if (activeWorkspaceRefreshPending && !activeWorkspaceRequestRunning) {
            activeWorkspaceRefreshPending = false;
            activeWorkspaceRequestRunning = true;
            SystemServices.requestHyprlandSnapshot("activeWorkspace", "activeworkspace");
        }
    }

    function queueRefreshForEvent(event) {
        if (!event || !event.name)
            return;

        const name = String(event.name);
        if (["openlayer", "closelayer", "screencast"].indexOf(name) !== -1)
            return;

        if (name === "configreloaded") {
            queueRefresh(true, true, true, true);
            return;
        }

        const affectsActiveWorkspace = name === "workspace"
            || name === "workspacev2"
            || name === "focusedmon"
            || name === "focusedmonv2";
        const affectsWorkspaces = affectsActiveWorkspace
            || name.indexOf("workspace") !== -1;
        const affectsMonitors = name.indexOf("monitor") !== -1
            || name === "focusedmon"
            || name === "focusedmonv2";
        const affectsClients = name.indexOf("window") !== -1
            || name === "changefloatingmode"
            || name === "fullscreen"
            || name === "pin"
            || name === "urgent"
            || name === "minimize"
            || name === "moveintogroup"
            || name === "moveoutofgroup"
            || name === "togglegroup";

        if (!affectsClients && !affectsMonitors && !affectsWorkspaces && !affectsActiveWorkspace)
            return;

        queueRefresh(affectsClients, affectsMonitors, affectsWorkspaces, affectsActiveWorkspace);
    }

    Component.onCompleted: updateAll()
    Component.onDestruction: {
        refreshTimer.stop();
    }

    Timer {
        id: refreshTimer

        interval: 90
        repeat: false

        onTriggered: root.flushRefresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            root.queueRefreshForEvent(event);
        }
    }

    Connections {
        target: SystemServices

        function onHyprlandSnapshotReady(requestId, subject, payloadJson, errorString) {
            if (requestId === "clients") {
                root.clientsRequestRunning = false;
                if (errorString === "") {
                    root.windowList = root.parseJson(payloadJson, []);
                    root.rebuildWindowIndex();
                    root.clientsReady = true;
                } else {
                    console.log("[HyprlandData] Failed to read clients:", errorString);
                }
            } else if (requestId === "monitors") {
                root.monitorsRequestRunning = false;
                if (errorString === "") {
                    root.monitors = root.parseJson(payloadJson, []);
                    root.monitorsReady = true;
                } else {
                    console.log("[HyprlandData] Failed to read monitors:", errorString);
                }
            } else if (requestId === "workspaces") {
                root.workspacesRequestRunning = false;
                if (errorString === "") {
                    const rawWorkspaces = root.parseJson(payloadJson, []);
                    root.workspaces = rawWorkspaces.filter((workspace) => workspace.id >= 1 && workspace.id <= 100);
                    root.workspacesReady = true;
                } else {
                    console.log("[HyprlandData] Failed to read workspaces:", errorString);
                }
            } else if (requestId === "activeWorkspace") {
                root.activeWorkspaceRequestRunning = false;
                if (errorString === "") {
                    root.activeWorkspace = root.parseJson(payloadJson, null);
                    root.activeWorkspaceReady = true;
                } else {
                    console.log("[HyprlandData] Failed to read active workspace:", errorString);
                }
            } else {
                return;
            }

            root.flushRefresh();
        }
    }
}
