import QtQuick
import QtQuick.Shapes
import qs

// halftone orb from the wallpaper: dots of one size, brightness set by a radial gradient. phase (s) is slow breathing
Shape {
    property real phase: 0

    width: 1100
    height: 1100
    opacity: 0.18 + 0.06 * Math.sin(phase * 2 * Math.PI / 8)
    layer.enabled: true
    layer.textureSize: Qt.size(320, 320) // gradient is smooth, dots take color from the cell center; extra pixels are unnecessary
    layer.effect: Dm { step: 14 }

    ShapePath {
        strokeWidth: -1
        fillGradient: RadialGradient {
            centerX: 352; centerY: 330; centerRadius: 730
            focalX: 352; focalY: 330
            GradientStop { position: 0; color: Theme.fg }
            GradientStop { position: 1; color: Theme.fade(Theme.fg, 0) }
        }
        PathAngleArc { centerX: 550; centerY: 550; radiusX: 550; radiusY: 550; startAngle: 0; sweepAngle: 360 }
    }
}
