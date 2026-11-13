import QtQuick
import Quickshell.Hyprland
import "../common"

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property var screenObject: null

    readonly property var monitor: screenObject
        ? Hyprland.monitorFor(screenObject)
        : Hyprland.focusedMonitor
    readonly property string monitorName: monitor && monitor.name ? String(monitor.name) : ""
    readonly property bool monitorFocused: monitor ? !!monitor.focused : false
    readonly property int workspaceId: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.id
        : 1

    HyprlandDispatch {
        id: dispatch
    }

    function focusWorkspace(workspace) {
        return dispatch.focusWorkspace(workspace);
    }
}
