import QtQuick
import qs

// canvas in 1920x1080 design pixels: stretched to the parent, inside everything is measured as in concept.html
Item {
    width: parent.width / Theme.s
    height: parent.height / Theme.s
    scale: Theme.s
    transformOrigin: Item.TopLeft
}
