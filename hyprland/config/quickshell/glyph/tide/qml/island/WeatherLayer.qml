pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import IslandBackend

FocusScope {
    id: root

    signal closeRequested()

    property bool showCondition: false
    property var weatherService: null
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property string heroFontFamily: ""

    focus: root.showCondition
    activeFocusOnTab: true
    anchors.fill: parent
    clip: true

    opacity: root.showCondition ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: StyleTokens.durationStandard
            easing.type: Easing.InOutQuad
        }
    }

    Keys.onEscapePressed: function(event) {
        root.closeRequested();
        event.accepted = true;
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        }
    }

    onShowConditionChanged: {
        if (root.showCondition) {
            root.forceActiveFocus();
            if (root.weatherService && !root.weatherService.hasData && root.weatherService.weatherEnabled) {
                root.weatherService.refresh();
            }
        }
    }

    // Background container layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // 1. TOP HEADER BAR
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8

            // Location pin icon
            Text {
                text: "\uf041" // nf-fa-map_marker
                color: StyleTokens.accent
                font.family: root.iconFontFamily && root.iconFontFamily.length > 0 ? root.iconFontFamily : "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }

            // Location text
            Text {
                text: (root.weatherService && root.weatherService.displayLocation.length > 0)
                    ? root.weatherService.displayLocation
                    : "Weather"
                color: StyleTokens.textPrimaryBright
                font.family: root.textFontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Status / Last updated
            Text {
                text: {
                    if (!root.weatherService) return "";
                    if (root.weatherService.loading) return "Updating...";
                    if (root.weatherService.isStale) return "Cached";
                    if (root.weatherService.lastUpdated) {
                        return "Updated " + Qt.formatTime(root.weatherService.lastUpdated, "hh:mm");
                    }
                    return "";
                }
                color: StyleTokens.textMuted
                font.family: root.textFontFamily
                font.pixelSize: 11
                Layout.alignment: Qt.AlignVCenter
                visible: text.length > 0
            }

            // Refresh Button
            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 13
                color: refreshMouse.containsMouse ? StyleTokens.moduleHover : StyleTokens.module

                Text {
                    id: refreshIcon
                    anchors.centerIn: parent
                    text: "\uf021" // nf-fa-refresh
                    color: refreshMouse.containsMouse ? StyleTokens.textPrimaryBright : StyleTokens.textSecondary
                    font.family: root.iconFontFamily && root.iconFontFamily.length > 0 ? root.iconFontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 12

                    RotationAnimation {
                        id: spinAnim
                        target: refreshIcon
                        property: "rotation"
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                        running: root.weatherService ? root.weatherService.loading : false
                    }
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.weatherService) root.weatherService.refresh();
                    }
                }
            }
        }

        // 2. MAIN CONTENT (HERO + METRICS + FORECAST)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading / Error state when no data
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: root.weatherService ? (!root.weatherService.hasData && (root.weatherService.loading || root.weatherService.isError)) : true

                Text {
                    text: (root.weatherService && root.weatherService.isError) ? "\uf071" : "\ue30d"
                    color: (root.weatherService && root.weatherService.isError) ? StyleTokens.warning : StyleTokens.accent
                    font.family: root.iconFontFamily && root.iconFontFamily.length > 0 ? root.iconFontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 36
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: (root.weatherService && root.weatherService.isError)
                        ? (root.weatherService.errorMessage.length > 0 ? root.weatherService.errorMessage : "Failed to load weather")
                        : "Fetching weather information..."
                    color: StyleTokens.textSecondary
                    font.family: root.textFontFamily
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    visible: root.weatherService ? root.weatherService.isError : false
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 28
                    radius: 14
                    color: retryHover.containsMouse ? StyleTokens.accentPressed : StyleTokens.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Retry"
                        color: StyleTokens.white
                        font.family: root.textFontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: retryHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.weatherService) root.weatherService.refresh();
                        }
                    }
                }
            }

            // Normal Loaded Content
            ColumnLayout {
                anchors.fill: parent
                spacing: 8
                visible: root.weatherService ? root.weatherService.hasData : false

                // HERO CARD
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    radius: 16
                    color: StyleTokens.module

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        // Left: Temperature & Condition
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            RowLayout {
                                spacing: 10

                                Text {
                                    text: root.weatherService ? root.weatherService.tempString : "--"
                                    color: StyleTokens.textPrimaryBright
                                    font.family: root.heroFontFamily
                                    font.pixelSize: 34
                                    font.weight: Font.Bold
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: root.weatherService ? root.weatherService.rangeString : ""
                                    color: StyleTokens.textMuted
                                    font.family: root.textFontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: text.length > 0
                                }
                            }

                            Text {
                                text: root.weatherService ? root.weatherService.condition : ""
                                color: StyleTokens.textSecondary
                                font.family: root.textFontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Right: Big Weather Icon
                        WeatherIcon {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52
                            Layout.alignment: Qt.AlignVCenter
                            weatherType: root.weatherService ? root.weatherService.weatherType : "sunny"
                            iconColor: root.weatherService ? root.weatherService.iconColor : "#f4c542"
                            glyph: root.weatherService ? root.weatherService.iconGlyph : "\ue30d"
                            iconFontFamily: root.iconFontFamily
                            iconSize: 52
                        }
                    }
                }

                // 4 METRICS TILES
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    spacing: 8

                    // Feels Like
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: 12
                        color: StyleTokens.module

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Text {
                                    text: "\uf2c9" // nf-fa-thermometer_half
                                    color: "#f18d41"
                                    font.family: root.iconFontFamily && root.iconFontFamily.length > 0 ? root.iconFontFamily : "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: "Feels Like"
                                    color: StyleTokens.textMuted
                                    font.family: root.textFontFamily
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                text: root.weatherService ? root.weatherService.feelsLikeString : "--"
                                color: StyleTokens.textPrimary
                                font.family: root.textFontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Humidity
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: 12
                        color: StyleTokens.module

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Text {
                                    text: "\uf043" // nf-fa-tint
                                    color: "#5f99fa"
                                    font.family: root.iconFontFamily && root.iconFontFamily.length > 0 ? root.iconFontFamily : "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: "Humidity"
                                    color: StyleTokens.textMuted
                                    font.family: root.textFontFamily
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                text: root.weatherService ? (root.weatherService.humidity + "%") : "--"
                                color: StyleTokens.textPrimary
                                font.family: root.textFontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Wind
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: 12
                        color: StyleTokens.module

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Text {
                                    text: "\ue321" // wi-strong-wind
                                    color: "#54e04b"
                                    font.family: root.iconFontFamily && root.iconFontFamily.length > 0 ? root.iconFontFamily : "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }

                                Text {
                                    text: "Wind"
                                    color: StyleTokens.textMuted
                                    font.family: root.textFontFamily
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                text: root.weatherService ? root.weatherService.windSpeedString : "--"
                                color: StyleTokens.textPrimary
                                font.family: root.textFontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // UV Index
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: 12
                        color: StyleTokens.module

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Text {
                                    text: "\ue30d" // wi-day-sunny
                                    color: "#f4c542"
                                    font.family: root.iconFontFamily && root.iconFontFamily.length > 0 ? root.iconFontFamily : "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: "UV Index"
                                    color: StyleTokens.textMuted
                                    font.family: root.textFontFamily
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                text: root.weatherService ? String(root.weatherService.uvIndex) : "--"
                                color: StyleTokens.textPrimary
                                font.family: root.textFontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                // BOTTOM SECTION: SUNRISE / SUNSET & 3-DAY FORECAST
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    // Sunrise & Sunset card
                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.fillHeight: true
                        radius: 12
                        color: StyleTokens.module

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: "\ue30c" // wi-sunrise
                                    color: "#ffcd58"
                                    font.family: root.iconFontFamily && root.iconFontFamily.length > 0 ? root.iconFontFamily : "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: (root.weatherService && root.weatherService.sunrise.length > 0) ? root.weatherService.sunrise : "--"
                                    color: StyleTokens.textSecondary
                                    font.family: root.textFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: "\ue301" // wi-sunset
                                    color: "#ff904d"
                                    font.family: root.iconFontFamily && root.iconFontFamily.length > 0 ? root.iconFontFamily : "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: (root.weatherService && root.weatherService.sunset.length > 0) ? root.weatherService.sunset : "--"
                                    color: StyleTokens.textSecondary
                                    font.family: root.textFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }

                    // 3-Day Forecast cards
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        Repeater {
                            model: root.weatherService ? root.weatherService.forecast : []

                            delegate: Rectangle {
                                id: forecastCard
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 12
                                color: StyleTokens.module

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        text: forecastCard.modelData.dayLabel
                                        color: StyleTokens.textMuted
                                        font.family: root.textFontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    WeatherIcon {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        Layout.alignment: Qt.AlignHCenter
                                        weatherType: forecastCard.modelData.weatherType
                                        iconColor: forecastCard.modelData.iconColor
                                        glyph: forecastCard.modelData.iconGlyph
                                        iconFontFamily: root.iconFontFamily
                                        iconSize: 22
                                    }

                                    Text {
                                        text: Math.round(forecastCard.modelData.maxTemp) + "° / " + Math.round(forecastCard.modelData.minTemp) + "°"
                                        color: StyleTokens.textSecondary
                                        font.family: root.textFontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
