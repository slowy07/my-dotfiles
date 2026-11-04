import QtQuick

// точечная маска для layer.effect: `layer.enabled: true; layer.effect: Dm { step: 6 }` — обложки, погода, шар на обоях
ShaderEffect {
    property real step: 5
    readonly property real pitch: step // uniform шейдера: имя step в GLSL занято
    property bool circle: false // точки только внутри круга
    readonly property real circ: circle ? 1 : 0
    readonly property size size: Qt.size(width, height)
    fragmentShader: Qt.resolvedUrl("shaders/dots.frag.qsb")
}
