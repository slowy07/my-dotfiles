pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Wayland blur regions have integer, binary edges. Keep them inside the
// antialiased outline and rasterize matching top/bottom corners ourselves:
// QRegion::Ellipse (used by Region.radius) has asymmetric scanlines.
Region {
    id: root

    property Item surface: null
    property real surfaceRadius: 0
    property bool active: false
    property var transformDependencies: []
    property int roundedRadius: 0

    // Subtract four matching corner strips from the rectangular base. Test the
    // outer edge of each row, so the whole blur pixel stays inside the curve.
    // Keep Region.radius at zero to bypass its integer ellipse rasterizer.
    readonly property Instantiator cornerStrips: Instantiator {
        model: root.roundedRadius
        delegate: Region {
            id: strip
            required property int index
            readonly property int cutout: Math.ceil(root.roundedRadius - Math.sqrt(
                Math.max(0, root.roundedRadius * root.roundedRadius
                    - Math.pow(root.roundedRadius - index, 2))))

            intersection: Intersection.Subtract
            x: root.x
            y: root.y + index
            width: cutout
            height: 1

            Region {
                x: root.x + root.width - strip.cutout
                y: strip.y
                width: strip.cutout
                height: 1
            }
            Region {
                x: root.x
                y: root.y + root.height - strip.index - 1
                width: strip.cutout
                height: 1
            }
            Region {
                x: root.x + root.width - strip.cutout
                y: root.y + root.height - strip.index - 1
                width: strip.cutout
                height: 1
            }
        }
        onObjectAdded: (index, object) => root.regions.push(object)
        onObjectRemoved: (index, object) => {
            const position = root.regions.indexOf(object);
            if (position >= 0)
                root.regions.splice(position, 1);
        }
    }

    function updateGeometry() {
        if (!active || !surface) {
            width = 0;
            height = 0;
            roundedRadius = 0;
            return;
        }

        const start = surface.mapToItem(null, 0, 0);
        const end = surface.mapToItem(null, surface.width, surface.height);
        const scale = surface.width > 0 ? (end.x - start.x) / surface.width : 1;
        const inset = scale; // One logical pixel beneath the fine surface outline.
        // Round inward on every side, including fractional output positions.
        const left = Math.ceil(start.x + inset);
        const top = Math.ceil(start.y + inset);
        const right = Math.floor(end.x - inset);
        const bottom = Math.floor(end.y - inset);
        x = left;
        y = top;
        width = Math.max(0, right - left);
        height = Math.max(0, bottom - top);
        roundedRadius = Math.max(0, Math.min(Math.floor(width / 2), Math.floor(height / 2),
            Math.ceil((surfaceRadius - 1) * scale)));
    }

    onActiveChanged: Qt.callLater(updateGeometry)
    onSurfaceChanged: Qt.callLater(updateGeometry)
    onSurfaceRadiusChanged: Qt.callLater(updateGeometry)
    onTransformDependenciesChanged: Qt.callLater(updateGeometry)

    readonly property Connections geometryChanges: Connections {
        target: root.surface
        function onXChanged() { Qt.callLater(root.updateGeometry); }
        function onYChanged() { Qt.callLater(root.updateGeometry); }
        function onWidthChanged() { Qt.callLater(root.updateGeometry); }
        function onHeightChanged() { Qt.callLater(root.updateGeometry); }
        function onScaleChanged() { Qt.callLater(root.updateGeometry); }
    }

    // Sample after all animation bindings, including ancestor transforms, have
    // settled for this frame. No timer or extra rendering pass is needed.
    readonly property Connections frameChanges: Connections {
        target: root.surface ? root.surface.Window.window : null
        function onAfterAnimating() { root.updateGeometry(); }
    }
}
