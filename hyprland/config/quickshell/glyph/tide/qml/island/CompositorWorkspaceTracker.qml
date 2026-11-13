import QtQuick
import IslandBackend

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string compositor: "hyprland"
    property var hyprMonitor: null
    property string hyprMonitorName: ""
    property string outputName: ""
    property bool monitorFocused: false
    property int currentWorkspaceId: 1
    property bool niriStateReady: false

    signal workspaceSynced(int workspaceId)
    signal workspaceActivated(int workspaceId)

    readonly property int compositorRevision: CompositorBackend.revision

    onCompositorChanged: {
        niriStateReady = false;
        syncNiriWorkspace(false);
    }
    onOutputNameChanged: {
        niriStateReady = false;
        syncNiriWorkspace(false);
    }
    onCompositorRevisionChanged: syncNiriWorkspace(true)
    Component.onCompleted: syncNiriWorkspace(false)

    function syncNiriWorkspace(announceChange) {
        if (compositor !== "niri")
            return;

        const workspaceId = CompositorBackend.activeWorkspaceIndexForOutput(outputName);
        if (workspaceId < 1)
            return;

        const changed = niriStateReady && workspaceId !== currentWorkspaceId;
        currentWorkspaceId = workspaceId;
        niriStateReady = true;
        workspaceSynced(workspaceId);
        if (announceChange && changed && monitorFocused)
            workspaceActivated(workspaceId);
    }

    Loader {
        id: hyprlandTrackerLoader

        active: root.compositor !== "niri"
        asynchronous: false
        visible: false
        source: active ? "HyprlandWorkspaceTracker.qml" : ""
    }

    Binding {
        target: hyprlandTrackerLoader.item
        property: "hyprMonitor"
        value: root.hyprMonitor
        when: hyprlandTrackerLoader.item !== null
    }

    Binding {
        target: hyprlandTrackerLoader.item
        property: "monitorName"
        value: root.hyprMonitorName
        when: hyprlandTrackerLoader.item !== null
    }

    Binding {
        target: hyprlandTrackerLoader.item
        property: "monitorFocused"
        value: root.monitorFocused
        when: hyprlandTrackerLoader.item !== null
    }

    Connections {
        target: hyprlandTrackerLoader.item

        function onWorkspaceSynced(workspaceId) {
            root.currentWorkspaceId = workspaceId;
            root.workspaceSynced(workspaceId);
        }

        function onWorkspaceActivated(workspaceId) {
            root.currentWorkspaceId = workspaceId;
            root.workspaceActivated(workspaceId);
        }
    }
}
