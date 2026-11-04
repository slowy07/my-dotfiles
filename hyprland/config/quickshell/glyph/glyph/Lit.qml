import QtQuick
import QtQuick.Effects
import qs
import qs.components

// шкала у края экрана: горящие сегменты светятся, погасшие лежат отдельно, без эффекта — иначе свечение обводило бы и серые
Item {
    id: root

    property int n
    property real f
    property bool vertical

    Seg { anchors.fill: parent; n: root.n; vertical: root.vertical; f: 0 }
    Seg {
        anchors.fill: parent
        n: root.n
        vertical: root.vertical
        f: root.f
        off: "transparent"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.glow
            shadowBlur: 0.7
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
