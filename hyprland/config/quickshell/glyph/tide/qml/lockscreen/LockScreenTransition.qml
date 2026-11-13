import QtQuick

Item {
    id: root

    property bool active: false
    property int enterDuration: 520
    property int exitDuration: 360
    property real entrance: 0
    property real departure: 0
    property string phase: "inactive"
    property bool initialized: false
    readonly property bool exiting: phase === "exiting"
    signal exitFinished()

    // One timeline drives every monitor. A removed screen cannot stall unlock.
    function enter() {
        if (!active) return;
        enterAnimation.stop();
        exitAnimation.stop();
        finishFrame.stop();
        entrance = 0;
        departure = 0;
        phase = "entering";
        enterAnimation.start();
    }

    function beginExit() {
        if (!active || exiting) return false;
        enterAnimation.stop();
        phase = "exiting";
        exitAnimation.start();
        return true;
    }

    onActiveChanged: {
        if (!initialized) return;
        if (active) {
            enter();
        } else {
            enterAnimation.stop();
            exitAnimation.stop();
            finishFrame.stop();
            phase = "inactive";
            entrance = 0;
            departure = 0;
        }
    }
    Component.onCompleted: { initialized = true; if (active) enter(); }

    NumberAnimation {
        id: enterAnimation
        target: root; property: "entrance"
        from: 0; to: 1; duration: root.enterDuration
        easing.type: Easing.Linear
        onFinished: if (root.active && root.phase === "entering") root.phase = "locked"
    }
    NumberAnimation {
        id: exitAnimation
        target: root; property: "departure"
        from: 0; to: 1; duration: root.exitDuration
        easing.type: Easing.InOutCubic
        onFinished: if (root.active && root.exiting) finishFrame.start()
    }
    Timer {
        id: finishFrame
        // Keep the lock until the final visual state has had a frame to render.
        interval: 20
        onTriggered: if (root.active && root.exiting) root.exitFinished()
    }
}
