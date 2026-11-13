import QtQuick

Item {
    id: root

    signal toggleRequested

    property bool active: false
    property bool hovered: false
    property bool animating: false
    property bool initialized: false

    width: 20
    height: 20
    opacity: active || animating ? 1 : (hovered ? 0.68 : 0)

    function showCurrentState() {
        outlineStar.opacity = active ? 0 : 1;
        outlineStar.scale = 1;
        filledStar.opacity = active ? 1 : 0;
        filledStar.scale = 1;
    }

    function playForCurrentState() {
        favoriteOnAnimation.stop();
        favoriteOffAnimation.stop();
        animating = true;
        if (active)
            favoriteOnAnimation.restart();
        else
            favoriteOffAnimation.restart();
    }

    Image {
        id: outlineStar

        anchors.centerIn: parent
        width: 18
        height: 18
        source: Qt.resolvedUrl("assets/star.svg")
        sourceSize: Qt.size(48, 48)
        smooth: true
        mipmap: true
    }

    Image {
        id: filledStar

        anchors.centerIn: parent
        width: 18
        height: 18
        source: Qt.resolvedUrl("assets/star-filled.svg")
        sourceSize: Qt.size(48, 48)
        smooth: true
        mipmap: true
    }

    SequentialAnimation {
        id: favoriteOnAnimation

        ScriptAction {
            script: {
                outlineStar.opacity = 1;
                outlineStar.scale = 1;
                filledStar.opacity = 0;
                filledStar.scale = 0.5;
            }
        }
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: outlineStar
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: 167
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    target: outlineStar
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: 166
                    easing.type: Easing.InOutCubic
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 66 }
                NumberAnimation {
                    target: filledStar
                    property: "scale"
                    from: 0.5
                    to: 1
                    duration: 267
                    easing.type: Easing.InOutCubic
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 66 }
                NumberAnimation {
                    target: filledStar
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 167
                    easing.type: Easing.InOutQuad
                }
            }
        }
        ScriptAction {
            script: {
                outlineStar.opacity = 0;
                root.animating = false;
                root.showCurrentState();
            }
        }
    }

    SequentialAnimation {
        id: favoriteOffAnimation

        ScriptAction {
            script: {
                outlineStar.opacity = 1;
                outlineStar.scale = 1;
                filledStar.opacity = 1;
                filledStar.scale = 1;
            }
        }
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: outlineStar
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: 167
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    target: outlineStar
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: 166
                    easing.type: Easing.InOutCubic
                }
            }
            NumberAnimation {
                target: filledStar
                property: "scale"
                from: 1
                to: 0.5
                duration: 267
                easing.type: Easing.InOutCubic
            }
            SequentialAnimation {
                PauseAnimation { duration: 100 }
                NumberAnimation {
                    target: filledStar
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 167
                    easing.type: Easing.InOutQuad
                }
            }
        }
        ScriptAction {
            script: {
                root.animating = false;
                root.showCurrentState();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.toggleRequested()
    }

    Component.onCompleted: {
        initialized = true;
        showCurrentState();
    }

    onActiveChanged: {
        if (initialized)
            playForCurrentState();
    }
}
