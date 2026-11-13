import QtQuick
import QtQuick.Window

Item {
    id: root
    property string imagePath: ""
    property bool previewActive: false
    property real devicePixelRatio: Screen.devicePixelRatio
    readonly property alias source: preview.source
    readonly property alias sourceSize: preview.sourceSize
    readonly property alias status: preview.status
    implicitWidth: preview.implicitWidth
    implicitHeight: preview.implicitHeight

    Image {
        id: preview
        anchors.centerIn: parent
        // Fit the display geometry separately: PreserveAspectFit also changes
        // Qt's decode sizing and can expand beyond the requested sourceSize.
        readonly property real fitScale: Math.min(root.width / Math.max(1, implicitWidth),
                                                 root.height / Math.max(1, implicitHeight))
        width: implicitWidth * fitScale
        height: implicitHeight * fitScale
        // Stable throughout the 520 x 400 capsule animation, including high DPI.
        sourceSize: Qt.size(Math.ceil(520 * Math.max(1, root.devicePixelRatio)),
                            Math.ceil(400 * Math.max(1, root.devicePixelRatio)))
        source: root.previewActive && root.imagePath !== "" ? ("file://" + root.imagePath) : ""
        asynchronous: true
        cache: false
    }
}
