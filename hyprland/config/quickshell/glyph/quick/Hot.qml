import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// горячий край: курсор задержался у правого края — быстрые настройки выезжают (Quick.peek). Полоска 2px по нижним 80%:
// верхний угол и полосы прокрутки у края почти не задевает
PanelWindow {
    id: root

    signal triggered

    visible: Theme.state.quickHover
    anchors { right: true; bottom: true }
    implicitWidth: 2
    implicitHeight: Math.round(screen.height * 0.8)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "glyph-hot"

    HoverHandler { id: hov; onHoveredChanged: hovered ? dwell.restart() : dwell.stop() }
    Timer { id: dwell; interval: 150; onTriggered: if (hov.hovered) root.triggered() }
}
