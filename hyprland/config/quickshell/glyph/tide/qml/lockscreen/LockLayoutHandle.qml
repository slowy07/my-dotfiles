pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var editor
    required property string widgetKey
    required property string label
    readonly property var card: parent
    anchors.fill: parent
    visible: editor.layoutEditing
    z: 100
    objectName: widgetKey + "LayoutHandle"

    Rectangle {
        anchors.fill: parent
        radius: root.card.radius
        color: "transparent"
        border.width: 2 * root.editor.editingUiScale
        border.color: Qt.alpha(root.editor.accent, dragArea.pressed ? 1 : 0.5)
    }
    Rectangle {
        x: 16
        y: -10 * root.editor.editingUiScale
        width: labelText.implicitWidth + 20 * root.editor.editingUiScale
        height: 22 * root.editor.editingUiScale
        radius: height / 2
        color: root.editor.accent
        Text {
            id: labelText
            anchors.centerIn: parent
            text: root.label
            color: "#ffffff"
            font.family: root.editor.textFont
            font.pixelSize: 11 * root.editor.editingUiScale
        }
    }
    MouseArea {
        id: dragArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: mouse => root.editor.beginMove(root.widgetKey, root.card, mapToItem(root.editor, mouse.x, mouse.y))
        onPositionChanged: mouse => {
            if (pressed)
                root.editor.moveWidget(mapToItem(root.editor, mouse.x, mouse.y));
        }
        onReleased: root.editor.finishMove()
        onCanceled: root.editor.cancelMove()
    }
}
