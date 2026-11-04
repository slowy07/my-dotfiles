import QtQuick
import qs

// холст в пикселях макета 1920×1080: растянут на родителя, внутри всё меряется как в concept.html
Item {
    width: parent.width / Theme.s
    height: parent.height / Theme.s
    scale: Theme.s
    transformOrigin: Item.TopLeft
}
