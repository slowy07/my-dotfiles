pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import IslandBackend

FocusScope {
    id: root

    signal closeRequested()

    property bool showCondition: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property string searchQuery: ""
    property int selectedIndex: 0
    property string deletingId: ""
    property string collapsingId: ""
    property bool imgFullPreview: false
    property int previewSlideDir: 1
    property int totalCount: 0
    property var allEntries: []
    property bool cliphistAvailable: true

    readonly property string helperScriptPath: {
        const candidate = Qt.resolvedUrl("../../scripts/cliphist-helper.sh").toString();
        if (candidate.startsWith("file://")) {
            return decodeURIComponent(candidate.substring(7));
        }
        return "/usr/share/tide-island/scripts/cliphist-helper.sh";
    }

    focus: showCondition
    activeFocusOnTab: true
    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.showCondition ? StyleTokens.durationStandard : StyleTokens.durationFast
            easing.type: Easing.InOutQuad
        }
    }

    Keys.onEscapePressed: function(event) {
        if (root.imgFullPreview) {
            root.imgFullPreview = false;
        } else {
            root.closeRequested();
        }
        event.accepted = true;
    }

    ListModel {
        id: listModel
    }

    onShowConditionChanged: {
        if (showCondition) {
            imgFullPreview = false;
            searchQuery = "";
            searchInput.text = "";
            selectedIndex = 0;
            refresh();
            grabKeyboardFocus();
        }
    }

    onSearchQueryChanged: {
        rebuildFilteredModel();
    }

    onImgFullPreviewChanged: {
        if (imgFullPreview) {
            previewArea.forceActiveFocus();
        } else {
            searchInput.forceActiveFocus();
        }
    }

    function grabKeyboardFocus() {
        root.focus = true;
        root.forceActiveFocus();
        if (imgFullPreview) {
            previewArea.forceActiveFocus();
        } else {
            searchInput.forceActiveFocus();
        }
    }

    function refresh() {
        listProc.running = false;
        listProc.running = true;
        countProc.running = false;
        countProc.running = true;
    }

    function rebuildFilteredModel() {
        listModel.clear();
        const q = searchQuery.trim().toLowerCase();
        const list = q.length === 0
            ? allEntries
            : allEntries.filter(e => {
                const labelStr = String(e.label).toLowerCase();
                if (labelStr.includes(q))
                    return true;
                if (e.imagePath && formatImageLabel(e.label).toLowerCase().includes(q))
                    return true;
                return false;
            });

        for (let i = 0; i < list.length; i++) {
            listModel.append(list[i]);
        }

        if (listModel.count === 0) {
            selectedIndex = -1;
        } else {
            selectedIndex = Math.max(0, Math.min(listModel.count - 1, selectedIndex));
        }
    }

    function copySelected() {
        if (listModel.count === 0 || selectedIndex < 0 || selectedIndex >= listModel.count)
            return;
        const entry = listModel.get(selectedIndex);
        copyEntry(entry);
    }

    function copyEntry(entry) {
        if (!entry || !entry.id)
            return;
        // The layer is unloaded on close; a child Process could be killed
        // before cliphist finishes restoring the selected item.
        Quickshell.execDetached(["bash", root.helperScriptPath, "copy", String(entry.id)]);
        root.closeRequested();
    }

    function deleteSelected() {
        if (listModel.count === 0 || selectedIndex < 0 || selectedIndex >= listModel.count)
            return;
        const entry = listModel.get(selectedIndex);
        deleteEntry(entry);
    }

    function deleteEntry(entry) {
        if (!entry || !entry.id)
            return;
        root.deletingId = String(entry.id);
        deleteProc.command = ["bash", root.helperScriptPath, "delete", String(entry.id), "true"];
        deleteProc.running = false;
        deleteProc.running = true;
        holdDeleteTimer.entryId = String(entry.id);
        holdDeleteTimer.restart();
    }

    function toggleImagePreview() {
        if (listModel.count === 0 || selectedIndex < 0 || selectedIndex >= listModel.count)
            return;
        const entry = listModel.get(selectedIndex);
        if (!entry || !entry.imagePath)
            return;
        imgFullPreview = !imgFullPreview;
    }

    function findAdjacentImageIndex(direction) {
        if (listModel.count === 0)
            return -1;
        let idx = root.selectedIndex;
        for (let i = 0; i < listModel.count; i++) {
            idx = (idx + direction + listModel.count) % listModel.count;
            const e = listModel.get(idx);
            if (e && e.imagePath)
                return idx;
        }
        return -1;
    }

    function formatImageLabel(raw) {
        if (!raw)
            return "Image";
        const match = String(raw).match(/\[\[ binary data (.+) \]\]/);
        if (match && match[1]) {
            const parts = match[1].trim().split(/\s+/);
            if (parts.length >= 3) {
                const res = parts[parts.length - 1].replace("x", "×");
                const fmt = parts[parts.length - 2].toUpperCase();
                const size = parts.slice(0, parts.length - 2).join(" ");
                return res + " • " + fmt + " (" + size + ")";
            }
            return match[1];
        }
        return String(raw);
    }

    function getClipType(entry) {
        if (!entry)
            return "text";
        if (entry.imagePath || entry.isImage)
            return "image";
        const str = String(entry.label).trim();
        if (/^#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(str)) {
            return "color";
        }
        if (/^(https?:\/\/|www\.|git@[\w.-]+:)/i.test(str)) {
            return "link";
        }
        if (/^(sudo\s|pacman\s|yay\s|git\s|cd\s|ls\s|rm\s|mkdir\s|curl\s|wget\s|systemctl\s|kill\s|grep\s|find\s|cat\s|echo\s|chmod\s|chown\s|ssh\s|docker\s|podman\s|cargo\s|npm\s|yarn\s|pnpm\s|python|node|bash|sh|zsh|powerprofilesctl)/.test(str)
            || (/^[\w./~-]+(\s+-[a-zA-Z0-9]+|\s+--[a-zA-Z0-9-]+)/.test(str))
            || (/[{};]/.test(str) && (str.includes("const ") || str.includes("let ") || str.includes("var ") || str.includes("function") || str.includes("class ") || str.includes("return ") || str.includes("#include") || str.includes("import ")))) {
            return "code";
        }
        return "text";
    }

    function getClipMeta(entry) {
        if (!entry)
            return "";
        if (entry.imagePath || entry.isImage)
            return "Image";
        const type = root.getClipType(entry);
        return type === "text" ? "Text" : type.charAt(0).toUpperCase() + type.slice(1);
    }

    Timer {
        id: holdDeleteTimer
        property string entryId: ""
        interval: 160
        repeat: false
        onTriggered: {
            root.collapsingId = entryId;
            removeTimer.entryId = entryId;
            removeTimer.restart();
        }
    }

    Timer {
        id: removeTimer
        property string entryId: ""
        interval: 200
        repeat: false
        onTriggered: {
            const currentIdx = root.selectedIndex;
            const savedContentY = listView.contentY;

            let idx = -1;
            for (let i = 0; i < listModel.count; i++) {
                if (listModel.get(i).id === entryId) {
                    idx = i;
                    break;
                }
            }
            if (idx !== -1)
                listModel.remove(idx);

            root.allEntries = root.allEntries.filter(e => e.id !== entryId);
            root.deletingId = "";
            root.collapsingId = "";

            const newLength = listModel.count;
            if (newLength === 0) {
                root.selectedIndex = -1;
                root.imgFullPreview = false;
            } else if (currentIdx >= newLength) {
                root.selectedIndex = newLength - 1;
            } else {
                root.selectedIndex = currentIdx;
            }

            if (root.imgFullPreview && root.selectedIndex !== -1) {
                const e = listModel.get(root.selectedIndex);
                if (!e || !e.imagePath) {
                    const imgIdx = root.findAdjacentImageIndex(root.previewSlideDir);
                    if (imgIdx !== -1) {
                        root.selectedIndex = imgIdx;
                    } else {
                        root.imgFullPreview = false;
                    }
                }
            }

            Qt.callLater(() => {
                const maxY = Math.max(0, listView.contentHeight - listView.height);
                listView.contentY = Math.min(savedContentY, maxY);
                if (root.selectedIndex >= 0)
                    listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            });
        }
    }

    Process {
        id: listProc
        command: ["bash", root.helperScriptPath, "list", "200"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.cliphistAvailable = true;
                const lines = this.text.split("\n").filter(l => l.length > 0);
                const parsed = [];
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    const tabIdx = line.indexOf("\t");
                    if (tabIdx === -1)
                        continue;
                    const id = line.substring(0, tabIdx);
                    const rest = line.substring(tabIdx + 1);
                    const nullIdx = rest.indexOf("\x00");
                    if (nullIdx !== -1) {
                        const label = rest.substring(0, nullIdx);
                        const iconPart = rest.substring(nullIdx + 1);
                        const splitPart = iconPart.split("\x1f");
                        const imgPath = splitPart.length > 1 ? splitPart[1] : "";
                        parsed.push({ id: id, label: label, imagePath: imgPath, isImage: true });
                    } else {
                        const isImg = rest.indexOf("[[ binary data") !== -1;
                        parsed.push({ id: id, label: rest, imagePath: "", isImage: isImg });
                    }
                }
                root.allEntries = parsed;
                root.rebuildFilteredModel();
            }
        }
        onExited: (code, status) => {
            if (code === 127)
                root.cliphistAvailable = false;
        }
    }

    Process {
        id: countProc
        command: ["bash", root.helperScriptPath, "count"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(this.text.trim(), 10);
                root.totalCount = isNaN(count) ? root.allEntries.length : count;
            }
        }
    }

    Process {
        id: deleteProc
        running: false
        onRunningChanged: {
            if (!running) {
                countProc.running = false;
                countProc.running = true;
            }
        }
    }

    Process {
        id: wipeProc
        command: ["bash", root.helperScriptPath, "wipe"]
        running: false
        onRunningChanged: {
            if (!running) {
                root.allEntries = [];
                listModel.clear();
                root.totalCount = 0;
                root.selectedIndex = -1;
                root.imgFullPreview = false;
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 14
        anchors.bottomMargin: 12
        spacing: 10
        clip: true

        // Header
        RowLayout {
            id: headerBar
            width: parent.width
            height: 28

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.imgFullPreview ? "Image Preview" : "Clipboard"
                textFormat: Text.PlainText
                color: StyleTokens.textPrimary
                font.pixelSize: 15
                font.family: root.textFontFamily
                font.weight: Font.DemiBold
            }

            Item {
                Layout.fillWidth: true
            }

            // Right: Count text + frameless wipe button (matching Notification Center style)
            Row {
                Layout.alignment: Qt.AlignRight
                spacing: 10
                visible: !root.imgFullPreview

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: listModel.count === 0
                        ? "0 items"
                        : (root.totalCount > listModel.count
                            ? (listModel.count + " of " + root.totalCount)
                            : (listModel.count + " items"))
                    color: StyleTokens.textDim
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                // Wipe history button (frameless, matching NotificationCenterLayer.qml style)
                Item {
                    id: wipeBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    opacity: listModel.count > 0 ? (wipeMouse.containsMouse ? 1 : 0.6) : 0.25

                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Item {
                        id: trashIcon
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        scale: wipeMouse.pressed ? 0.70 : 0.75

                        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                        Shape {
                            id: trashBodyShape
                            x: 0
                            y: wipeMouse.containsMouse ? 1 : 0
                            width: parent.width
                            height: parent.height
                            preferredRendererType: Shape.CurveRenderer

                            Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

                            ShapePath {
                                fillColor: StyleTokens.transparent
                                strokeColor: wipeMouse.containsMouse ? "#ff453a" : StyleTokens.textDim
                                strokeWidth: 1.8
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin

                                PathSvg {
                                    path: "M5 6v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V6 M10 11v6 M14 11v6"
                                }
                            }
                        }

                        Item {
                            id: trashLidItem
                            x: 0
                            transformOrigin: Item.Right
                            y: wipeMouse.containsMouse ? -1.5 : 0
                            width: parent.width
                            height: parent.height
                            rotation: wipeMouse.containsMouse ? 12 : 0

                            Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                            Behavior on rotation { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

                            Shape {
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: StyleTokens.transparent
                                    strokeColor: wipeMouse.containsMouse ? "#ff453a" : StyleTokens.textDim
                                    strokeWidth: 1.8
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin

                                    PathSvg {
                                        path: "M3 6h18 M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: wipeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: listModel.count > 0
                        onClicked: {
                            wipeProc.running = false;
                            wipeProc.running = true;
                        }
                    }
                }
            }
        }

        // Search surface matches the wallpaper picker.
        Rectangle {
            id: searchContainer
            width: parent.width
            height: 34
            radius: 10
            color: Qt.rgba(1, 1, 1, searchInput.activeFocus ? 0.09 : 0.06)
            border.color: Qt.rgba(1, 1, 1, 0.16)
            border.width: searchInput.activeFocus ? 1 : 0
            visible: !root.imgFullPreview

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 9

                // Magnifying glass icon
                Item {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: StyleTokens.transparent
                            strokeColor: Qt.rgba(1, 1, 1, searchInput.activeFocus ? 0.65 : 0.38)
                            strokeWidth: 1.4
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin

                            PathSvg {
                                path: "M6.5 11.5a5 5 0 1 0 0-10 5 5 0 0 0 0 10z M10 10l3.5 3.5"
                            }
                        }
                    }
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#ffffff"
                    font.family: root.textFontFamily
                    font.pixelSize: 12
                    clip: true
                    selectByMouse: true
                    selectedTextColor: "#ffffff"
                    selectionColor: "#58616f"

                    onTextChanged: {
                        root.searchQuery = text;
                    }

                    Text {
                        text: "Search clipboard history…"
                        color: Qt.rgba(1, 1, 1, 0.28)
                        font: searchInput.font
                        visible: searchInput.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Down) {
                            if (listModel.count > 0) {
                                root.selectedIndex = (root.selectedIndex + 1) % listModel.count;
                                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (listModel.count > 0) {
                                root.selectedIndex = root.selectedIndex <= 0
                                    ? listModel.count - 1
                                    : root.selectedIndex - 1;
                                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.copySelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            event.accepted = true;
                            root.closeRequested();
                        } else if (event.key === Qt.Key_Delete) {
                            root.deleteSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            root.toggleImagePreview();
                            event.accepted = true;
                        }
                    }
                }

                // Clear query button
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 10
                    color: clearQueryMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    visible: searchInput.text.length > 0

                    Shape {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: StyleTokens.transparent
                            strokeColor: clearQueryMouse.containsMouse ? "#ffffff" : "#8f929d"
                            strokeWidth: 1.3
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin

                            PathSvg {
                                path: "M1 1l6 6 M7 1l-6 6"
                            }
                        }
                    }

                    MouseArea {
                        id: clearQueryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════
        // MAIN CONTENT AREA: LIST VIEW OR FULL IMAGE PREVIEW
        // ══════════════════════════════════════════════
        Item {
            width: parent.width
            height: parent.height - (root.imgFullPreview ? 38 : 84)
            clip: true

            // ──────────────────────────────────────────
            // FULL IMAGE PREVIEW MODE
            // ──────────────────────────────────────────
            FocusScope {
                id: previewArea
                anchors.fill: parent
                visible: root.imgFullPreview
                focus: root.imgFullPreview

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                        const next = root.findAdjacentImageIndex(1);
                        if (next !== -1) {
                            root.previewSlideDir = 1;
                            root.selectedIndex = next;
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                        const prev = root.findAdjacentImageIndex(-1);
                        if (prev !== -1) {
                            root.previewSlideDir = -1;
                            root.selectedIndex = prev;
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.copySelected();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Delete) {
                        root.deleteSelected();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab) {
                        root.imgFullPreview = false;
                        event.accepted = true;
                    }
                }

                readonly property var currentEntry: {
                    if (root.selectedIndex >= 0 && root.selectedIndex < listModel.count)
                        return listModel.get(root.selectedIndex);
                    return null;
                }

                readonly property string currentImgPath: currentEntry && currentEntry.imagePath
                    ? currentEntry.imagePath
                    : ""

                Column {
                    anchors.fill: parent
                    spacing: 8

                    // Image container card
                    Rectangle {
                        width: parent.width
                        height: parent.height - 34
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 0
                        clip: true

                        ClipboardPreviewImage {
                            id: fullPreviewImg
                            anchors.centerIn: parent
                            width: parent.width - 24
                            height: parent.height - 24
                            imagePath: previewArea.currentImgPath
                            previewActive: root.showCondition && root.imgFullPreview

                            property real slideY: 0
                            transform: Translate { y: fullPreviewImg.slideY }

                            onSourceChanged: {
                                slideY = root.previewSlideDir * 24;
                                slideAnim.restart();
                            }

                            NumberAnimation {
                                id: slideAnim
                                target: fullPreviewImg
                                property: "slideY"
                                to: 0
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Top-left image info badge
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 10
                            height: 24
                            width: previewInfoText.implicitWidth + 18
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.62)
                            border.width: 0

                            Text {
                                id: previewInfoText
                                anchors.centerIn: parent
                                text: previewArea.currentEntry
                                    ? root.formatImageLabel(previewArea.currentEntry.label)
                                    : "Image"
                                color: "#ffffff"
                                font.family: root.textFontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }

                        // Deletion flash overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "#ff3b30"
                            opacity: (previewArea.currentEntry && String(previewArea.currentEntry.id) === root.deletingId) ? 0.65 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        // Deletion label
                        Text {
                            anchors.centerIn: parent
                            text: "Deleted"
                            color: "#ffffff"
                            font.family: root.textFontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            opacity: (previewArea.currentEntry && String(previewArea.currentEntry.id) === root.deletingId) ? 1 : 0
                            scale: (previewArea.currentEntry && String(previewArea.currentEntry.id) === root.deletingId) ? 1 : 0.85
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        }
                    }

                    // Quiet footer for keyboard shortcuts and the primary action.
                    RowLayout {
                        width: parent.width
                        height: 26

                        Text {
                            Layout.alignment: Qt.AlignLeft
                            text: "↑↓ Browse   ·   Del Delete   ·   Esc Back"
                            color: StyleTokens.textDim
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Copy button
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 24
                            radius: 12
                            color: copyBtnMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.18)
                                : Qt.rgba(1, 1, 1, 0.10)
                            border.width: 0

                            Text {
                                anchors.centerIn: parent
                                text: "Copy"
                                color: StyleTokens.textPrimary
                                font.family: root.textFontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: copyBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copySelected()
                            }
                        }
                    }
                }
            }

            // ──────────────────────────────────────────
            // NORMAL LIST VIEW MODE
            // ──────────────────────────────────────────
            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                model: listModel
                currentIndex: root.selectedIndex
                highlightFollowsCurrentItem: false
                visible: !root.imgFullPreview && listModel.count > 0
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    id: vbar
                    active: listView.moving || listView.dragging
                    width: 3
                    policy: listView.contentHeight > listView.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 1.5
                        color: "#5b5e68"
                        opacity: 0.6
                    }
                }

                delegate: Rectangle {
                    id: rowDelegate
                    required property int index
                    required property var model

                    readonly property string clipType: root.getClipType(rowDelegate.model)
                    readonly property bool isSelected: rowDelegate.index === root.selectedIndex
                    readonly property bool isDeleting: String(rowDelegate.model.id) === root.deletingId
                    readonly property bool isCollapsing: String(rowDelegate.model.id) === root.collapsingId

                    width: listView.width - (vbar.visible ? 7 : 0)
                    height: isCollapsing
                        ? 0
                        : (rowDelegate.model.imagePath !== "" ? 60 : 46)
                    radius: 12
                    clip: true
                    opacity: isCollapsing ? 0 : 1
                    scale: isCollapsing ? 0.85 : 1

                    color: {
                        if (isDeleting)
                            return Qt.rgba(1, 0.25, 0.22, 0.16);
                        if (isSelected)
                            return Qt.rgba(1, 1, 1, 0.11);
                        if (rowMouse.containsMouse)
                            return Qt.rgba(1, 1, 1, 0.08);
                        return Qt.rgba(1, 1, 1, 0.05);
                    }

                    border.color: {
                        if (isDeleting)
                            return Qt.rgba(1, 0.25, 0.22, 0.45);
                        if (isSelected)
                            return Qt.rgba(1, 1, 1, 0.16);
                        return "transparent";
                    }
                    border.width: isSelected || isDeleting ? 1 : 0

                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Behavior on border.color { ColorAnimation { duration: 110 } }

                    // Keep the row target behind the action buttons so each
                    // button receives its own click instead of copying the row.
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: (mouse) => {
                            root.selectedIndex = rowDelegate.index;
                            if (mouse.button === Qt.RightButton)
                                root.deleteEntry(rowDelegate.model);
                            else
                                root.copyEntry(rowDelegate.model);
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 11
                        anchors.rightMargin: 8
                        spacing: 10

                        // ── TYPE BADGE / THUMBNAIL ──
                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: rowDelegate.model.imagePath !== "" ? 48 : 28
                            Layout.preferredHeight: rowDelegate.model.imagePath !== "" ? 44 : 28

                            // Image thumbnail preview
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 0
                                clip: true
                                visible: rowDelegate.model.imagePath !== ""

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    fillMode: Image.PreserveAspectFit
                                    source: rowDelegate.model.imagePath ? ("file://" + rowDelegate.model.imagePath) : ""
                                    asynchronous: true
                                    cache: false
                                    sourceSize: Qt.size(96, 88)
                                }
                            }

                            // Color chip preview
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 0
                                visible: rowDelegate.clipType === "color"

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: rowDelegate.clipType === "color" ? String(rowDelegate.model.label).trim() : "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.25)
                                }
                            }

                            // Link and code use the same quiet surface as text.
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 0
                                visible: rowDelegate.clipType === "link"

                                Shape {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    preferredRendererType: Shape.CurveRenderer

                                    ShapePath {
                                        fillColor: StyleTokens.transparent
                                        strokeColor: StyleTokens.textDim
                                        strokeWidth: 1.3
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin

                                        PathSvg {
                                            path: "M6 8.5a3 3 0 0 1 0-4.24l2-2a3 3 0 0 1 4.24 4.24l-1 1 M8 5.5a3 3 0 0 1 0 4.24l-2 2a3 3 0 0 1-4.24-4.24l1-1"
                                        }
                                    }
                                }
                            }

                            // Code / command
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 0
                                visible: rowDelegate.clipType === "code"

                                Shape {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    preferredRendererType: Shape.CurveRenderer

                                    ShapePath {
                                        fillColor: StyleTokens.transparent
                                        strokeColor: StyleTokens.textDim
                                        strokeWidth: 1.3
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin

                                        PathSvg {
                                            path: "M3 4l4 3-4 3 M8 10h4"
                                        }
                                    }
                                }
                            }

                            // Standard text badge
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 0
                                visible: rowDelegate.clipType === "text"

                                Shape {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    preferredRendererType: Shape.CurveRenderer

                                    ShapePath {
                                        fillColor: StyleTokens.transparent
                                        strokeColor: StyleTokens.textDim
                                        strokeWidth: 1.3
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin

                                        PathSvg {
                                            path: "M3 2h5.5l3.5 3.5V12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z M8.5 2v3.5H12 M4.5 7.5h5 M4.5 9.5h3.5"
                                        }
                                    }
                                }
                            }
                        }

                        // ── TEXT CONTENT COLUMN ──
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: rowDelegate.model.imagePath !== ""
                                    ? root.formatImageLabel(rowDelegate.model.label)
                                    : rowDelegate.model.label
                                color: rowDelegate.isSelected ? "#ffffff" : "#eaecf2"
                                font.family: root.textFontFamily
                                font.pixelSize: 12
                                font.weight: rowDelegate.isSelected ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                            }

                            Text {
                                width: parent.width
                                text: root.getClipMeta(rowDelegate.model)
                                color: StyleTokens.textDim
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                font.weight: Font.Normal
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        // Actions remain visible and sit above the row target.
                        Row {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            // Copy micro-button (frameless icon matching Notification Center style)
                            Item {
                                width: 22
                                height: 22
                                opacity: copyActionMouse.containsMouse ? 1 : 0.65

                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Shape {
                                    anchors.centerIn: parent
                                    width: 13
                                    height: 13
                                    scale: copyActionMouse.pressed ? 0.85 : 1.0
                                    preferredRendererType: Shape.CurveRenderer

                                    Behavior on scale { NumberAnimation { duration: 150 } }

                                    ShapePath {
                                        fillColor: StyleTokens.transparent
                                        strokeColor: copyActionMouse.containsMouse ? StyleTokens.textPrimary : StyleTokens.textDim
                                        strokeWidth: 1.4
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin

                                        PathSvg {
                                            path: "M4.5 2.5h5a1 1 0 0 1 1 1v6 M2.5 5.5h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1v-5a1 1 0 0 1 1-1z"
                                        }
                                    }
                                }

                                MouseArea {
                                    id: copyActionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.copyEntry(rowDelegate.model);
                                    }
                                }
                            }

                            // Delete micro-button (frameless icon matching Notification Center style)
                            Item {
                                width: 22
                                height: 22
                                opacity: deleteActionMouse.containsMouse ? 1 : 0.65

                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Shape {
                                    anchors.centerIn: parent
                                    width: 13
                                    height: 13
                                    scale: deleteActionMouse.pressed ? 0.85 : 1.0
                                    preferredRendererType: Shape.CurveRenderer

                                    Behavior on scale { NumberAnimation { duration: 150 } }

                                    ShapePath {
                                        fillColor: StyleTokens.transparent
                                        strokeColor: deleteActionMouse.containsMouse ? "#ff453a" : StyleTokens.textDim
                                        strokeWidth: 1.4
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin

                                        PathSvg {
                                            path: "M1.5 3h9 M4 3V1.8h4V3 M2.5 3l.6 7.5a1 1 0 0 0 1 .9h3.8a1 1 0 0 0 1-.9l.6-7.5"
                                        }
                                    }
                                }

                                MouseArea {
                                    id: deleteActionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.deleteEntry(rowDelegate.model);
                                    }
                                }
                            }
                        }
                    }

                }
            }

            // Smooth bottom fade into curved capsule base
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 18
                enabled: false
                visible: !root.imgFullPreview && listView.contentHeight > listView.height

                gradient: Gradient {
                    GradientStop { position: 0.0; color: StyleTokens.transparent }
                    GradientStop { position: 1.0; color: "#0b0c0f" }
                }
                opacity: 0.8
            }

            // ──────────────────────────────────────────
            // EMPTY OR NOT FOUND STATE
            // ──────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: !root.imgFullPreview && listModel.count === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 32
                        height: 32

                        Shape {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: StyleTokens.transparent
                                strokeColor: StyleTokens.textDim
                                strokeWidth: 1.4
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin

                                PathSvg {
                                    path: root.searchQuery !== ""
                                        ? "M7.5 13.5a6 6 0 1 0 0-12 6 6 0 0 0 0 12z M12 12l4 4"
                                        : "M5 3.5H3.5A1.5 1.5 0 0 0 2 5v11a1.5 1.5 0 0 0 1.5 1.5h9a1.5 1.5 0 0 0 1.5-1.5V5a1.5 1.5 0 0 0-1.5-1.5H11 M5 2.5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1.5H5V2.5z"
                                }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !root.cliphistAvailable
                            ? "cliphist or wl-clipboard not found"
                            : (root.searchQuery !== "" ? "No matching clips" : "Clipboard is empty")
                        color: "#e2e4ea"
                        font.family: root.textFontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !root.cliphistAvailable
                            ? "Install cliphist and wl-clipboard to enable clipboard history"
                            : (root.searchQuery !== "" ? "Try a different search keyword" : "Items you copy will automatically appear here")
                        color: "#6b6e7a"
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
