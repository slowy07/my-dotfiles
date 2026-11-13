import QtQuick
import IslandBackend

Item {
    id: root

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string iconText: ""
    property bool expanded: false
    property int toggleButton: Qt.LeftButton
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string iconFontFamily: activeConfig.iconFontFamily
    property string textFontFamily: activeConfig.textFontFamily
    property string heroFontFamily: activeConfig.heroFontFamily

    signal expansionToggleRequested()

    readonly property string contentText: {
        var raw;
        if (summary !== "" && body !== "" && body !== summary) raw = summary + "  " + body;
        else if (summary !== "") raw = summary;
        else if (body !== "") raw = body;
        else raw = "New notification";
        var words = raw.split(/\s+/);
        if (words.length > 30) return words.slice(0, 30).join(" ") + "...";
        return raw;
    }
    readonly property real minimumWidth: userConfig.islandWidth
    readonly property real compactMaximumWidth: 400
    readonly property real expandedMaximumWidth: 520
    readonly property real maximumWidth: expanded && hasOverflowContent ? expandedMaximumWidth : compactMaximumWidth
    readonly property real iconSlotWidth: 18
    readonly property real contentSpacing: 13
    readonly property real horizontalPadding: 16
    readonly property real compactVerticalPadding: 4
    readonly property real expandedVerticalPadding: 13
    readonly property real verticalPadding: expanded && hasOverflowContent ? expandedVerticalPadding : compactVerticalPadding
    readonly property real compactMaximumContentHeight: userConfig.islandHeight - compactVerticalPadding * 2
    readonly property real expandedMaximumContentHeight: 240 - expandedVerticalPadding * 2
    readonly property real textBlockWidthAtMaximum: compactMaximumWidth - horizontalPadding * 2 - iconSlotWidth - contentSpacing
    readonly property real expandedTextBlockWidthAtMaximum: expandedMaximumWidth - horizontalPadding * 2 - iconSlotWidth - contentSpacing
    readonly property real availableWidth: Math.max(0, width - horizontalPadding * 2 - iconSlotWidth - contentSpacing)
    readonly property bool prefersWrappedContent: contentMetrics.advanceWidth > textBlockWidthAtMaximum
    readonly property bool hasOverflowContent: compactContentProbe.lineCount > 2
        || contentMetrics.advanceWidth > textBlockWidthAtMaximum * 2
        || (contentMetrics.advanceWidth > textBlockWidthAtMaximum && compactContentProbe.lineCount <= 1)
    readonly property real compactPreferredWidth: prefersWrappedContent
        ? maximumWidth
        : Math.max(minimumWidth, Math.min(maximumWidth, contentMetrics.advanceWidth + iconSlotWidth + contentSpacing + horizontalPadding * 2))
    readonly property real compactPreferredHeight: prefersWrappedContent ? compactMaximumContentHeight + compactVerticalPadding * 2 : userConfig.islandHeight
    readonly property real expandedPreferredWidth: expandedMaximumWidth
    readonly property real expandedPreferredHeight: Math.max(
        84,
        Math.min(240, Math.min(expandedMaximumContentHeight, expandedContentProbe.implicitHeight) + expandedVerticalPadding * 2)
    )
    readonly property real preferredWidth: expanded && hasOverflowContent ? expandedPreferredWidth : compactPreferredWidth
    readonly property real preferredHeight: expanded && hasOverflowContent ? expandedPreferredHeight : compactPreferredHeight

    anchors.fill: parent
    anchors.margins: 0
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 280 : 140
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: contentMetrics
        font.family: textFontFamily
        font.pixelSize: userConfig.bodyFontSize
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        text: contentText
    }

    Text {
        id: compactContentProbe
        x: -10000
        y: -10000
        height: 0
        opacity: 0
        width: textBlockWidthAtMaximum
        text: contentText
        font.pixelSize: userConfig.bodyFontSize
        font.family: textFontFamily
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        wrapMode: Text.WordWrap
        lineHeight: 0.95
    }

    Text {
        id: expandedContentProbe
        x: -10000
        y: -10000
        height: 0
        opacity: 0
        width: expandedTextBlockWidthAtMaximum
        text: contentText
        font.pixelSize: userConfig.bodyFontSize
        font.family: textFontFamily
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        wrapMode: Text.WordWrap
        lineHeight: 1.05
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: horizontalPadding
        anchors.rightMargin: horizontalPadding
        anchors.topMargin: verticalPadding
        anchors.bottomMargin: verticalPadding
        spacing: contentSpacing
        anchors.verticalCenter: parent.verticalCenter

        Text {
            width: iconSlotWidth
            anchors.verticalCenter: parent.verticalCenter
            text: iconText
            color: StyleTokens.textPrimary
            font.pixelSize: userConfig.iconFontSize
            font.family: iconFontFamily
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            width: parent.width - iconSlotWidth - contentSpacing
            height: parent.height

            Text {
                visible: !(root.expanded && root.hasOverflowContent)
                anchors.verticalCenter: parent.verticalCenter
                text: contentText
                color: StyleTokens.textPrimary
                font.pixelSize: userConfig.bodyFontSize
                font.family: textFontFamily
                font.weight: Font.DemiBold
                font.letterSpacing: -0.15
                width: parent.width
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                elide: Text.ElideRight
                lineHeight: 0.95
            }

            Flickable {
                id: expandedFlickable
                visible: root.expanded && root.hasOverflowContent
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: expandedContentText.implicitHeight
                interactive: contentHeight > height

                Text {
                    id: expandedContentText
                    width: expandedFlickable.width
                    text: contentText
                    color: StyleTokens.textPrimary
                    font.pixelSize: userConfig.bodyFontSize
                    font.family: textFontFamily
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.15
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    lineHeight: 1.05
                }
            }
        }
    }

    TapHandler {
        enabled: root.hasOverflowContent
        acceptedButtons: root.toggleButton
        onTapped: root.expansionToggleRequested()
    }
}
