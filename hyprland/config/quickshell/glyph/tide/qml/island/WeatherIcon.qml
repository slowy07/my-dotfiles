pragma ComponentBehavior: Bound

import QtQuick
import IslandBackend

Item {
    id: root

    property string weatherType: "sunny"
    property string glyph: ""
    property string iconColor: "#f4c542"
    property string iconFontFamily: ""
    property real iconSize: 28

    width: iconSize
    height: iconSize

    readonly property string resolvedGlyph: {
        if (root.glyph && root.glyph.length > 0)
            return root.glyph;
        switch (root.weatherType) {
        case "sunny":
        case "clear":
            return "\ue30d"; // wi-day-sunny
        case "partly_cloudy":
        case "partly-cloudy":
            return "\ue302"; // wi-day-cloudy
        case "cloudy":
        case "overcast":
            return "\ue312"; // wi-cloudy
        case "rain":
        case "drizzle":
        case "heavy_rain":
        case "heavy-rain":
            return "\ue318"; // wi-rain
        case "thunder":
        case "storm":
        case "thunderstorm":
            return "\ue31d"; // wi-thunderstorm
        case "snow":
        case "sleet":
        case "blizzard":
            return "\ue31a"; // wi-snow
        case "fog":
        case "mist":
        case "haze":
            return "\ue313"; // wi-fog
        default:
            return "\ue312"; // wi-cloudy fallback
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.resolvedGlyph
        color: root.iconColor
        font.family: root.iconFontFamily && root.iconFontFamily.length > 0
            ? root.iconFontFamily
            : "JetBrainsMono Nerd Font"
        font.pixelSize: Math.round(root.iconSize)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
