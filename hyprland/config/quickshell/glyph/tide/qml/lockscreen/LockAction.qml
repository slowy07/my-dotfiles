import QtQuick
import QtQuick.Controls

Button {
    id: root
    property string glyph: "play"
    property bool prominent: false
    property bool selected: false
    property bool transport: false
    property var styleTokens: null
    property color accent: styleTokens ? styleTokens.accent : "#0a84ff"
    property color foreground: styleTokens ? styleTokens.textPrimary : "#f5f5f7"
    property color buttonFill: styleTokens ? styleTokens.buttonFill : "#f5f5f7"
    property color buttonFillHover: styleTokens ? styleTokens.buttonFillHover : "#ffffff"
    property color buttonFillPressed: styleTokens ? styleTokens.buttonFillPressed : "#e9e9ec"
    implicitWidth: 48
    implicitHeight: 48
    padding: 0
    hoverEnabled: true
    Accessible.name: text
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        radius: 12
        color: root.prominent ? (root.down ? root.buttonFillPressed : root.hovered ? root.buttonFillHover : root.buttonFill) : root.down ? "#10ffffff" : root.hovered ? "#08ffffff" : "transparent"
        border.width: root.activeFocus ? 1.5 : 0
        border.color: root.accent
        antialiasing: true
        Behavior on scale {
            NumberAnimation {
                duration: 110
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }
    contentItem: Item {
        LockGlyph {
            anchors.centerIn: parent
            width: root.transport ? (root.glyph === "heart" ? 24 : 28) : 20
            height: width
            name: root.glyph
            ink: root.prominent ? "#202125" : root.down ? "#b6b6bf" : root.foreground
            filled: root.glyph === "heart" ? root.selected : root.transport
            scale: root.down ? 0.84 : 1
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    ToolTip.visible: hovered && text.length > 0
    ToolTip.text: text
    ToolTip.delay: 650
}
