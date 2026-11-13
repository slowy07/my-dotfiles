import QtQuick
import IslandBackend
import "../common"

Item {
    id: shell

    property bool open: false
    property bool mounted: false
    property var provider: null
    property var mainCapsule: null
    property real availableWidth: 0
    property string textFontFamily: ""
    property string heroFontFamily: ""
    property real revealProgress: 0
    readonly property alias surfaceItem: panelBody
    readonly property real panelScale: 0.96 + revealProgress * 0.04

    readonly property real detailGap: 16
    readonly property real capsuleX: mainCapsule ? mainCapsule.x : 0
    readonly property real capsuleY: mainCapsule ? mainCapsule.y : 0
    readonly property real capsuleWidth: mainCapsule ? mainCapsule.width : 0
    readonly property real capsuleHeight: mainCapsule ? mainCapsule.height : 0
    readonly property bool rightSide: capsuleX + capsuleWidth + detailGap + width <= availableWidth - 16
        || capsuleX - width - detailGap < 16
    readonly property real shownX: rightSide
        ? Math.min(availableWidth - width - 16, capsuleX + capsuleWidth + detailGap)
        : Math.max(16, capsuleX - width - detailGap)
    readonly property real hiddenX: shownX + (rightSide ? -12 : 12)
    readonly property real hiddenY: capsuleY + (capsuleHeight - height) / 2 + 4

    x: hiddenX + (shownX - hiddenX) * revealProgress
    y: hiddenY + (capsuleY + (capsuleHeight - height) / 2 - hiddenY) * revealProgress
    width: 304
    height: 304
    opacity: revealProgress
    visible: mounted
    z: 3

    function syncDraft() {
        const nextText = shell.provider ? shell.provider.noteDraft : "";
        if (noteInput.text !== nextText) {
            noteInput.text = nextText;
            noteScroll.contentY = 0;
        }
    }

    function focusEditor() {
        if (shell.open && shell.provider)
            noteInput.forceActiveFocus();
    }

    function animateOpen(nextOpen) {
        revealAnimation.stop();
        if (nextOpen) {
            hideTimer.stop();
            mounted = true;
            syncDraft();
            revealAnimation.to = 1;
            revealAnimation.duration = 240;
            revealAnimation.easing.type = Easing.OutCubic;
            revealAnimation.start();
            Qt.callLater(shell.focusEditor);
        } else {
            revealAnimation.to = 0;
            revealAnimation.duration = 160;
            revealAnimation.easing.type = Easing.OutCubic;
            revealAnimation.start();
            hideTimer.restart();
        }
    }

    onOpenChanged: animateOpen(open)
    onProviderChanged: syncDraft()

    Component.onCompleted: {
        mounted = open;
        revealProgress = open ? 1 : 0;
        syncDraft();
        if (open)
            Qt.callLater(shell.focusEditor);
    }

    NumberAnimation {
        id: revealAnimation
        target: shell
        property: "revealProgress"
    }

    Timer {
        id: hideTimer
        interval: 190
        repeat: false
        onTriggered: {
            if (!shell.open)
                shell.mounted = false;
        }
    }

    Connections {
        target: shell.provider
        ignoreUnknownSignals: true

        function onNoteDraftChanged() {
            shell.syncDraft();
        }
    }

    Item {
        id: panelBody
        anchors.fill: parent
        transform: Scale {
            origin.x: shell.rightSide ? 0 : panelBody.width
            origin.y: panelBody.height / 2
            xScale: shell.panelScale
            yScale: shell.panelScale
        }

        GlassSurface {
            anchors.fill: parent
            radius: 28
            clip: true

            Text {
                id: noteDateLabel
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 22
                anchors.topMargin: 20
                text: shell.provider ? shell.provider.selectedDateFullText : ""
                color: StyleTokens.textPrimary
                font.family: shell.heroFontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                anchors.left: noteDateLabel.left
                anchors.top: noteDateLabel.bottom
                anchors.topMargin: 3
                text: "Note"
                color: StyleTokens.textDim
                font.family: shell.textFontFamily
                font.pixelSize: 11
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 18
                anchors.topMargin: 19
                width: 26
                height: 26
                radius: 13
                color: closeMouse.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.13)
                    : Qt.rgba(1, 1, 1, 0.06)

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: StyleTokens.textSecondary
                    font.family: shell.textFontFamily
                    font.pixelSize: 17
                    font.weight: Font.Light
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (shell.provider)
                            shell.provider.closeNote();
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.topMargin: 72
                height: 1
                color: Qt.rgba(1, 1, 1, 0.09)
            }

            Flickable {
                id: noteScroll
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.bottomMargin: 22
                anchors.topMargin: 89
                clip: true
                contentWidth: width
                contentHeight: Math.max(height, noteInput.paintedHeight + 4)
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: noteInput
                    width: noteScroll.width
                    height: Math.max(noteScroll.height, paintedHeight + 4)
                    color: StyleTokens.textPrimary
                    font.family: shell.textFontFamily
                    font.pixelSize: 13
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    selectByMouse: true
                    selectedTextColor: "#1b1c20"
                    selectionColor: "#d7e3f1"

                    onTextChanged: {
                        if (shell.provider)
                            shell.provider.setNoteDraft(text);
                    }

                    onCursorRectangleChanged: {
                        const bottom = cursorRectangle.y + cursorRectangle.height;
                        if (bottom > noteScroll.contentY + noteScroll.height)
                            noteScroll.contentY = bottom - noteScroll.height;
                        else if (cursorRectangle.y < noteScroll.contentY)
                            noteScroll.contentY = cursorRectangle.y;
                    }

                    Keys.onEscapePressed: function(event) {
                        if (shell.provider)
                            shell.provider.closeNote();
                        event.accepted = true;
                    }
                }

                Text {
                    visible: noteInput.text.length === 0
                    text: "Write anything…"
                    color: StyleTokens.textDim
                    font.family: shell.textFontFamily
                    font.pixelSize: 13
                }
            }
        }
    }
}
