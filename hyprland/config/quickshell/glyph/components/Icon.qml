import QtQuick
import qs

// Nerd Font glyph (Material Design). 1em box, like line-height: 1 in the concept (NF line is 1.32em)
Text {
    readonly property real lead: -0.16 * font.pixelSize
    font { family: Theme.nf; pixelSize: 19 }
    topPadding: lead
    bottomPadding: lead
    color: Theme.fg
}
