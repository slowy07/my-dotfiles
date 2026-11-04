import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import "charms.js" as Data

// чары: каомодзи, эмодзи и символы. Панель из семьи буфера: поиск-пилюля, вкладки чипами (Tab),
// слева сетка плиток, справа выбранное крупно. Выбранная плитка — белая. ⏎ — в буфер, вставляешь сам Ctrl+V
PanelWindow {
    id: root

    readonly property var tabs: ["kaomoji", "emoji", "symbols"]
    readonly property var cols: [2, 8, 8]
    property int tab: 0
    property int sel: 0
    // ё → е: в словах CLDR «черный», а пишут и так и так
    readonly property string query: input.text.toLowerCase().replace(/ё/g, "е")

    readonly property var lists: [Data.KAOMOJI, Data.EMOJI, Data.SYMBOLS]
    // слова в charms.js уже строчные — без toLowerCase и деструктуризации: по 1900 эмодзи это кадр на каждую букву.
    // Сам символ («Ω», «Ψ») — строчными, но только если слова не совпали
    readonly property var view: query ? lists[tab].filter(e => e[1].includes(query) || e[0].toLowerCase().includes(query)) : lists[tab]
    readonly property var cur: view[sel] ?? null

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    function open() {
        input.text = "";
        sel = 0;
        shown = true;
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    function go(i) { if (view.length) sel = Math.max(0, Math.min(i, view.length - 1)); }

    function fire() {
        if (!cur) return;
        Quickshell.execDetached(["wl-copy", "--", cur[0]]);
        close();
    }

    onQueryChanged: sel = 0
    onTabChanged: { sel = 0; grids.itemAt(tab)?.positionViewAtBeginning(); }
    onSelChanged: grids.itemAt(tab)?.positionViewAtIndex(sel, GridView.Contain)
    onVisibleChanged: if (visible) input.forceActiveFocus()

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-charms"

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: 140 + 24 * (1 - root.t)
            width: 1120
            height: Math.min(stage.height - 280, 760)
            opacity: root.t
            radius: 44
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            MouseArea { anchors.fill: parent }

            Rectangle {
                id: search
                x: 34
                y: 30
                width: parent.width - 68
                height: 66
                radius: 33
                color: Theme.s2

                Icon { id: lens; x: 24; anchors.verticalCenter: parent.verticalCenter; text: "\u{F0349}"; color: Theme.grey; font.pixelSize: 22 }
                TextInput {
                    id: input
                    focus: true
                    anchors { left: lens.right; leftMargin: 16; right: chips.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font { family: Theme.ui; pixelSize: 22 }
                    color: Theme.fg
                    selectionColor: Theme.s3
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.red
                        Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    Text {
                        visible: !input.text
                        x: 6
                        text: "Search charms"
                        font: input.font
                        color: Theme.mute
                    }
                    // ponytail: ←→ ходят по сетке, а не по тексту — запросы тут в одно слово
                    Keys.onPressed: e => {
                        const n = root.cols[root.tab];
                        if (e.key === Qt.Key_Escape) root.close();
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.fire();
                        else if (e.key === Qt.Key_Tab) root.tab = (root.tab + 1) % 3;
                        else if (e.key === Qt.Key_Backtab) root.tab = (root.tab + 2) % 3;
                        else if (e.key === Qt.Key_Left) root.go(root.sel - 1);
                        else if (e.key === Qt.Key_Right) root.go(root.sel + 1);
                        else if (e.key === Qt.Key_Up) root.go(root.sel - n);
                        else if (e.key === Qt.Key_Down) root.go(root.sel + n);
                        else return;
                        e.accepted = true;
                    }
                }
                Row {
                    id: chips
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: root.tabs
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: chip.width + 32
                            height: chip.height + 20
                            radius: height / 2
                            color: root.tab === index ? Theme.fg : "transparent"
                            Lb { id: chip; anchors.centerIn: parent; text: parent.modelData; px: 11; color: root.tab === parent.index ? Theme.ink : Theme.grey }
                            TapHandler { onTapped: { root.tab = parent.index; input.forceActiveFocus(); } }
                        }
                    }
                }
            }

            Row {
                id: head
                x: 42
                y: search.y + search.height + 30
                spacing: 14
                Num { anchors.baseline: hlab.baseline; text: root.view.length; font.pixelSize: 34 }
                Lb { id: hlab; text: root.tabs[root.tab] }
            }

            // по сетке на вкладку, живут все три: Tab только прячет — пересборка плиток стоила кадры. Без запроса у всех
            // полный список и от tab модели не зависят; поиск фильтрует только видимую
            Item {
                id: grid
                anchors { left: parent.left; leftMargin: 34; top: head.bottom; topMargin: 18; bottom: parent.bottom; bottomMargin: 34 }
                width: 620

                Repeater {
                    id: grids
                    model: 3

                    GridView {
                        id: g
                        required property int index
                        anchors.fill: parent
                        visible: root.tab === index
                        clip: true
                        cellWidth: width / root.cols[index]
                        cellHeight: index === 0 ? 76 : cellWidth
                        model: root.query && root.tab === index ? root.view : root.lists[index]
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Item {
                            id: d
                            required property var modelData
                            required property int index
                            readonly property bool on: root.sel === index
                            width: g.cellWidth
                            height: g.cellHeight

                            Rectangle {
                                anchors { fill: parent; margins: 3 }
                                radius: Math.min(width, height) / 2
                                color: d.on ? Theme.fg : Theme.s2
                                // Fit — лишние раскладки на каждой плитке; нужен длинным каомодзи и ZWJ-эмодзи: шрифт постарше
                                // не склеит последовательность, и она развалится на 2–4 глифа шире клетки
                                Text {
                                    anchors { fill: parent; margins: 8 }
                                    text: d.modelData[0]
                                    textFormat: Text.PlainText
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    fontSizeMode: g.index === 0 || d.modelData[0].includes("\u200d") ? Text.Fit : Text.FixedSize
                                    minimumPixelSize: 6
                                    font { family: Theme.mono; pixelSize: g.index === 0 ? 20 : 32 }
                                    color: d.on ? Theme.ink : Theme.fg
                                }
                            }
                            // клик — выбрать, по выбранной — скопировать
                            TapHandler { onTapped: d.on ? root.fire() : root.sel = d.index }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // выбранное крупно
            Rectangle {
                id: card
                anchors { left: grid.right; leftMargin: 24; right: parent.right; rightMargin: 34; top: head.top; bottom: parent.bottom; bottomMargin: 34 }
                radius: 40
                color: Theme.s2

                Lb { id: kindLb; x: 30; y: 30; text: root.cur ? `${root.sel + 1} of ${root.view.length}` : "" }
                Text {
                    anchors { left: parent.left; right: parent.right; top: kindLb.bottom; bottom: keys.top; margins: 30 }
                    text: root.cur?.[0] ?? ""
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 8
                    font { family: Theme.mono; pixelSize: 140 }
                    color: Theme.fg
                }
                Lb {
                    id: keys
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 30 }
                    elide: Text.ElideRight
                    text: root.cur?.[1] ?? ""
                }
                Lb { anchors.centerIn: parent; visible: !root.cur; text: "no matches" }
            }

            Row {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 28 }
                spacing: 34
                Repeater {
                    model: ["←↑↓→ select", "↵ copy", "tab section", "esc close"]
                    Lb { required property string modelData; text: modelData }
                }
            }
        }
    }
}
