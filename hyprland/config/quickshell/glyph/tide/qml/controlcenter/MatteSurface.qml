import QtQuick
import IslandBackend

Item {
    id: root

    property real radius: 20
    property bool hovered: false
    property bool pressed: false
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.hovered ? StyleTokens.cardFillHover : StyleTokens.cardFillActive
        border.width: 1
        border.color: root.hovered ? StyleTokens.surfaceBorder : StyleTokens.surfaceHighlight

        Behavior on color {
            ColorAnimation { duration: StyleTokens.durationFast }
        }
    }
}
