import QtQuick
import qs

// метка: Space Mono капсом, трекинг .14em, серая. Размер — px (а не font.pixelSize: трекинг считается от него)
Text {
    property real px: 12
    font { family: Theme.mono; pixelSize: px; letterSpacing: px * 0.14; capitalization: Font.AllUppercase }
    color: Theme.grey
}
