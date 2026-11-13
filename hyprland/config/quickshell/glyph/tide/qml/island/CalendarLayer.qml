pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Io
import IslandBackend

FocusScope {
    id: root

    signal closeRequested()

    property bool showCondition: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property string heroFontFamily: ""

    // Current navigation state
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property int selectedYear: new Date().getFullYear()
    property int selectedMonth: new Date().getMonth()
    property int selectedDay: new Date().getDate()
    property bool noteOpen: false
    property string activeDateKey: ""
    property string noteDraft: ""
    property var notes: ({})
    property bool notesHydrated: false

    // Fixed today references
    readonly property var todayDate: new Date()
    readonly property int todayYear: todayDate.getFullYear()
    readonly property int todayMonth: todayDate.getMonth()
    readonly property int todayDay: todayDate.getDate()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    readonly property var monthNamesShort: [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    readonly property var dayNames: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    readonly property var weekdayNamesFull: [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]

    property var calendarCells: []

    readonly property string selectedDateFullText: {
        const d = new Date(root.selectedYear, root.selectedMonth, root.selectedDay);
        const dayName = root.weekdayNamesFull[d.getDay()];
        const monthName = root.monthNamesShort[root.selectedMonth];
        return dayName + ", " + root.selectedDay + " " + monthName + " " + root.selectedYear;
    }

    readonly property string relativeDateText: {
        const sel = new Date(root.selectedYear, root.selectedMonth, root.selectedDay);
        const tod = new Date(root.todayYear, root.todayMonth, root.todayDay);
        const diffMs = sel.getTime() - tod.getTime();
        const diffDays = Math.round(diffMs / 86400000);

        if (diffDays === 0) return "Today";
        if (diffDays === 1) return "Tomorrow";
        if (diffDays === -1) return "Yesterday";
        if (diffDays > 1) return "In " + diffDays + " days";
        return Math.abs(diffDays) + " days ago";
    }

    readonly property int selectedWeekNumber: {
        return root.getWeekNumber(root.selectedYear, root.selectedMonth, root.selectedDay);
    }

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
        if (root.noteOpen)
            root.closeNote();
        else
            root.closeRequested();
        event.accepted = true;
    }

    Keys.onLeftPressed: function(event) {
        root.prevMonth();
        event.accepted = true;
    }

    Keys.onRightPressed: function(event) {
        root.nextMonth();
        event.accepted = true;
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Home) {
            root.goToToday();
            event.accepted = true;
        }
    }

    WheelHandler {
        orientation: Qt.Vertical
        onWheel: event => {
            if (event.angleDelta.y > 0) {
                root.prevMonth();
            } else if (event.angleDelta.y < 0) {
                root.nextMonth();
            }
        }
    }

    onShowConditionChanged: {
        if (root.showCondition) {
            root.forceActiveFocus();
            root.goToToday();
        } else {
            root.flushNote();
        }
    }

    Component.onCompleted: {
        root.updateCalendarModel();
    }
    Component.onDestruction: root.flushNote()

    FileView {
        id: notesFile
        path: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)
            + "/tide-island/calendar-notes.json"
        preload: true
        atomicWrites: true
        printErrors: false

        JsonAdapter {
            id: noteStore
            property var notes: ({})
        }

        onLoaded: {
            if (!root.notesHydrated)
                root.loadNotes();
        }
    }

    Timer {
        id: saveNoteTimer
        interval: 350
        repeat: false
        onTriggered: root.flushNote()
    }

    function dateKey(y, m, d) {
        const month = m + 1;
        return y + "-" + (month < 10 ? "0" : "") + month
            + "-" + (d < 10 ? "0" : "") + d;
    }

    function loadNotes() {
        let stored = {};
        try {
            const contents = notesFile.text();
            if (contents.trim() !== "") {
                const parsed = JSON.parse(contents);
                if (parsed && parsed.notes && typeof parsed.notes === "object"
                        && !Array.isArray(parsed.notes))
                    stored = parsed.notes;
            }
        } catch (error) {
            stored = {};
        }
        root.notes = stored;
        root.notesHydrated = true;
    }

    function hasNote(y, m, d) {
        const content = root.notes[root.dateKey(y, m, d)];
        return typeof content === "string" && content.trim() !== "";
    }

    function saveNote(key, content) {
        if (key === "")
            return;
        const previous = root.notes[key] || "";
        if (previous === content)
            return;

        const updated = Object.assign({}, root.notes);
        if (content.trim() === "")
            delete updated[key];
        else
            updated[key] = content;
        root.notes = updated;
        noteStore.notes = updated;
        notesFile.writeAdapter();
        notesFile.waitForJob();
    }

    function flushNote() {
        if (!root.noteOpen)
            return;
        saveNoteTimer.stop();
        root.saveNote(root.activeDateKey, root.noteDraft);
    }

    function openNote(y, m, d) {
        if (!root.notesHydrated) {
            notesFile.waitForJob();
            root.loadNotes();
        }
        const key = root.dateKey(y, m, d);
        root.activeDateKey = key;
        root.noteDraft = root.notes[key] || "";
        root.noteOpen = true;
    }

    function setNoteDraft(content) {
        if (root.noteDraft === content)
            return;
        root.noteDraft = content;
        if (root.noteOpen)
            saveNoteTimer.restart();
    }

    function closeNote() {
        root.flushNote();
        root.noteOpen = false;
        root.forceActiveFocus();
    }

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate();
    }

    function daysInPrevMonth(y, m) {
        return new Date(y, m, 0).getDate();
    }

    // Monday-based first day of week: 0 = Monday, ..., 6 = Sunday
    function firstDayOfWeek(y, m) {
        const day = new Date(y, m, 1).getDay();
        return (day + 6) % 7;
    }

    function updateCalendarModel() {
        const cells = [];
        const firstDay = root.firstDayOfWeek(root.viewYear, root.viewMonth);
        const daysCur = root.daysInMonth(root.viewYear, root.viewMonth);
        const daysPrev = root.daysInPrevMonth(root.viewYear, root.viewMonth);

        for (let i = 0; i < 42; i++) {
            let d, m, y, isCur = false;
            if (i < firstDay) {
                d = daysPrev - firstDay + i + 1;
                m = (root.viewMonth === 0 ? 11 : root.viewMonth - 1);
                y = (root.viewMonth === 0 ? root.viewYear - 1 : root.viewYear);
            } else if (i < firstDay + daysCur) {
                d = i - firstDay + 1;
                m = root.viewMonth;
                y = root.viewYear;
                isCur = true;
            } else {
                d = i - (firstDay + daysCur) + 1;
                m = (root.viewMonth === 11 ? 0 : root.viewMonth + 1);
                y = (root.viewMonth === 11 ? root.viewYear + 1 : root.viewYear);
            }

            cells.push({
                day: d,
                month: m,
                year: y,
                isCurMonth: isCur
            });
        }
        root.calendarCells = cells;
    }

    function prevMonth() {
        if (viewMonth === 0) {
            viewMonth = 11;
            viewYear -= 1;
        } else {
            viewMonth -= 1;
        }
        root.updateCalendarModel();
    }

    function nextMonth() {
        if (viewMonth === 11) {
            viewMonth = 0;
            viewYear += 1;
        } else {
            viewMonth += 1;
        }
        root.updateCalendarModel();
    }

    function goToToday() {
        const now = new Date();
        viewYear = now.getFullYear();
        viewMonth = now.getMonth();
        selectedYear = now.getFullYear();
        selectedMonth = now.getMonth();
        selectedDay = now.getDate();
        root.updateCalendarModel();
    }

    function selectDate(y, m, d) {
        root.flushNote();
        const target = new Date(y, m, d);
        const targetY = target.getFullYear();
        const targetM = target.getMonth();
        const targetD = target.getDate();

        const monthChanged = (targetY !== root.viewYear || targetM !== root.viewMonth);
        root.selectedYear = targetY;
        root.selectedMonth = targetM;
        root.selectedDay = targetD;
        root.viewYear = targetY;
        root.viewMonth = targetM;

        if (monthChanged) {
            root.updateCalendarModel();
        }
        root.openNote(targetY, targetM, targetD);
    }

    function getWeekNumber(y, m, d) {
        const target = new Date(Date.UTC(y, m, d));
        target.setUTCDate(target.getUTCDate() + 4 - (target.getUTCDay() || 7));
        const yearStart = new Date(Date.UTC(target.getUTCFullYear(), 0, 1));
        return Math.ceil((((target.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8

            // Calendar icon
            Shape {
                Layout.preferredWidth: 15
                Layout.preferredHeight: 15
                preferredRendererType: Shape.CurveRenderer
                Layout.alignment: Qt.AlignVCenter

                ShapePath {
                    fillColor: StyleTokens.transparent
                    strokeColor: StyleTokens.textDim
                    strokeWidth: 1.4
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathSvg {
                        path: "M3 4a1.5 1.5 0 0 1 1.5-1.5h6A1.5 1.5 0 0 1 12 4v8a1.5 1.5 0 0 1-1.5 1.5h-6A1.5 1.5 0 0 1 3 12V4zm0 2.5h9M5 1.5v2M10 1.5v2"
                    }
                }
            }

            // Month and year
            Text {
                text: root.monthNames[root.viewMonth] + " " + root.viewYear
                color: StyleTokens.textPrimary
                font.family: root.textFontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.letterSpacing: -0.2
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            // Today stays available without competing with the selected date.
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: todayLabel.implicitWidth + 18
                radius: 12
                color: todayMouse.containsMouse
                    ? StyleTokens.cardFillHover
                    : StyleTokens.cardFillActive
                border.width: 0

                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    id: todayLabel
                    anchors.centerIn: parent
                    text: "Today"
                    color: todayMouse.containsMouse ? StyleTokens.textPrimary : StyleTokens.textSecondary
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToToday()
                }
            }

            // Previous Month Button
            Item {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter

                Shape {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    scale: prevMouse.pressed ? 0.85 : (prevMouse.containsMouse ? 1.08 : 1.0)
                    preferredRendererType: Shape.CurveRenderer
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    ShapePath {
                        fillColor: StyleTokens.transparent
                        strokeColor: prevMouse.containsMouse ? StyleTokens.textPrimaryBright : StyleTokens.textDim
                        strokeWidth: 1.5
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathSvg {
                            path: "M9 3L4 7.5L9 12"
                        }
                    }
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.prevMonth()
                }
            }

            // Next Month Button
            Item {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter

                Shape {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    scale: nextMouse.pressed ? 0.85 : (nextMouse.containsMouse ? 1.08 : 1.0)
                    preferredRendererType: Shape.CurveRenderer
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    ShapePath {
                        fillColor: StyleTokens.transparent
                        strokeColor: nextMouse.containsMouse ? StyleTokens.textPrimaryBright : StyleTokens.textDim
                        strokeWidth: 1.5
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathSvg {
                            path: "M5 3L10 7.5L5 12"
                        }
                    }
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextMonth()
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: StyleTokens.surfaceHighlight
        }

        // Weekday labels
        Grid {
            id: dayNamesGrid
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            columns: 7
            columnSpacing: 4

            readonly property real colWidth: Math.max(0, (width - 6 * columnSpacing) / 7)

            Repeater {
                model: root.dayNames

                delegate: Item {
                    id: dayHeaderItem
                    required property string modelData
                    required property int index

                    width: dayNamesGrid.colWidth
                    height: dayNamesGrid.height

                    Text {
                        anchors.centerIn: parent
                        text: dayHeaderItem.modelData
                        color: dayHeaderItem.index >= 5
                            ? StyleTokens.textTertiary
                            : StyleTokens.textMuted
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // Six stable rows keep the capsule height fixed while changing months.
        Grid {
            id: daysGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            columnSpacing: 4
            rowSpacing: 3

            readonly property real cellWidth: Math.max(0, (width - 6 * columnSpacing) / 7)
            readonly property real cellHeight: Math.max(0, (height - 5 * rowSpacing) / 6)

            Repeater {
                model: root.calendarCells

                delegate: Rectangle {
                    id: cellRect
                    required property var modelData
                    required property int index

                    width: daysGrid.cellWidth
                    height: daysGrid.cellHeight
                    radius: 7

                    readonly property int cellDay: modelData.day
                    readonly property int cellMonth: modelData.month
                    readonly property int cellYear: modelData.year
                    readonly property bool isCurMonth: modelData.isCurMonth

                    readonly property bool isToday: cellYear === root.todayYear
                        && cellMonth === root.todayMonth
                        && cellDay === root.todayDay

                    readonly property bool isSelected: cellYear === root.selectedYear
                        && cellMonth === root.selectedMonth
                        && cellDay === root.selectedDay

                    color: cellMouse.containsMouse
                        ? StyleTokens.cardFillHover
                        : StyleTokens.transparent
                    border.width: 0

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Rectangle {
                        id: dateMark
                        anchors.centerIn: parent
                        width: Math.min(30, parent.width - 4)
                        height: Math.min(30, parent.height - 2)
                        radius: width / 2
                        color: cellRect.isToday
                            ? StyleTokens.buttonFill
                            : (cellRect.isSelected ? StyleTokens.cardFillActive : StyleTokens.transparent)
                        border.width: cellRect.isSelected && !cellRect.isToday ? 1 : 0
                        border.color: StyleTokens.surfaceBorder

                        Text {
                            anchors.centerIn: parent
                            text: String(cellRect.cellDay)
                            font.family: root.textFontFamily
                            font.pixelSize: 12
                            font.weight: (cellRect.isToday || cellRect.isSelected) ? Font.DemiBold : Font.Normal
                            color: cellRect.isToday
                                ? StyleTokens.panel
                                : (cellRect.isCurMonth ? StyleTokens.textPrimary : StyleTokens.textDim)
                        }
                    }

                    Rectangle {
                        x: dateMark.x + dateMark.width - 1
                        y: dateMark.y - 2
                        width: 5
                        height: 5
                        radius: 2.5
                        color: StyleTokens.textPrimary
                        visible: root.hasNote(cellRect.cellYear, cellRect.cellMonth, cellRect.cellDay)
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectDate(cellRect.cellYear, cellRect.cellMonth, cellRect.cellDay);
                        }
                    }
                }
            }
        }

        // A single quiet detail line replaces the stacked badges.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 28

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: StyleTokens.surfaceHighlight
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                anchors.topMargin: 3
                spacing: 8

                Text {
                    text: root.selectedDateFullText
                    color: StyleTokens.textSecondary
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.relativeDateText + "  ·  W" + root.selectedWeekNumber
                    color: StyleTokens.textDim
                    font.family: root.textFontFamily
                    font.pixelSize: 10
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
