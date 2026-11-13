import QtQuick

Rectangle {
    id: root
    property var styleTokens: null
    property real surfaceOpacity: 0.82
    property color surfaceColor: styleTokens ? styleTokens.panel : "#202125"
    property color outlineColor: styleTokens ? styleTokens.surfaceBorder : "#26ffffff"
    property real entrance: 1
    property real departure: 0
    property real stagger: 0
    readonly property real reveal: {
        const progress = Math.max(0, Math.min(1, (entrance - stagger) / 0.7));
        return 1 - Math.pow(1 - progress, 3);
    }
    readonly property real dismiss: Math.max(0, Math.min(1, (departure - stagger * 0.35) / 0.78))
    opacity: reveal * Math.pow(1 - dismiss, 2)
    scale: 0.985 + 0.015 * reveal - 0.018 * dismiss
    transform: Translate {
        y: (1 - root.reveal) * 26 - root.dismiss * 16
    }
    radius: styleTokens ? styleTokens.radiusPanel : 28
    color: Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, surfaceOpacity)
    border.width: surfaceOpacity > 0 ? 1 : 0
    border.color: outlineColor
    antialiasing: true

    // Match GlassSurface's restrained highlight without blurring the content.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        visible: root.surfaceOpacity > 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#0cffffff"
            }
            GradientStop {
                position: 0.45
                color: "#02ffffff"
            }
            GradientStop {
                position: 1
                color: "#04000000"
            }
        }
    }
}
