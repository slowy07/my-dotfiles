import QtQuick
import IslandBackend

// The compositor blurs what is behind the window. This layer gives that
// material its tint and a quiet edge without blurring foreground content.
Rectangle {
    id: root

    property real materialOpacity: 0.82
    property color tint: StyleTokens.panel

    radius: StyleTokens.radiusPanel
    color: Qt.rgba(tint.r, tint.g, tint.b, materialOpacity)
    border.width: 1
    border.color: StyleTokens.surfaceBorder
    antialiasing: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0; color: "#0cffffff" }
            GradientStop { position: 0.45; color: "#02ffffff" }
            GradientStop { position: 1; color: "#04000000" }
        }
    }
}
