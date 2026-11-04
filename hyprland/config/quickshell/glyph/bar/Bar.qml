import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.settings

// бар: горизонтальный convex в духе minflair — сплошная полоса-позвоночник сверху, три наплыва с вогнутыми
// шейками: слева знак, воркспейсы и заголовок, в центре часы, справа трей, режим и питание.
// Цвета — everblush (s1/fg/grey/s3). Знак — кольцо из 16 точек, центр краснеет, пока запись или микрофон.
// Что в трее и в каком порядке, есть ли заголовок — Theme.state (настройки, раздел BAR)
PanelWindow {
    id: root

    signal markClicked
    signal trayClicked
    signal powerClicked
    signal clockClicked

    anchors { top: true; left: true; right: true }
    implicitHeight: Math.ceil(44 * Theme.s)
    color: "transparent"
    WlrLayershell.namespace: "glyph-bar"

    readonly property int active: Hyprland.focusedWorkspace?.id ?? 0
    // шесть точек, больше — если занят или открыт дальний
    readonly property int count: Math.min(10, Math.max(6, active, ...Hyprland.workspaces.values.filter(w => w.toplevels.values.length).map(w => w.id)))
    readonly property var top: ToplevelManager.activeToplevel
    readonly property var bat: UPower.displayDevice
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null

    // hyprland 0.56 с lua: dispatch принимает lua-выражение
    function go(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`); }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Stage {
        id: stage

        // convex в духе minflair: полоса 8 сверху, наплывы высотой 44, шейки 18×16 с радиусом 16.
        // Ширины наплывов — по содержимому, центр всегда посередине
        readonly property int baseH: 44
        readonly property int spine: 8
        readonly property int flareW: 18
        readonly property int flareH: 16
        readonly property int corner: 16
        readonly property int pad: 26
        readonly property real leftW: leftRow.width + pad * 2
        readonly property real rightW: rightRow.width + pad * 2
        readonly property real centerW: clk.width + flareW * 2 + 36
        readonly property real centerX: Math.round((width - centerW) / 2)

        // путь: левый наплыв -> шейка -> часы -> шейка -> правый наплыв. Свободные углы скруглены,
        // у краёв экрана прямые — бар примыкает к краю, как convex у minflair
        function barPath() {
            const w = width, h = baseH, tb = spine, fw = flareW, fh = flareH, br = corner;
            const lW = leftW, cX = centerX, cW = centerW, rX = w - rightW;
            let p = `M 0 0 `;
            p += `L 0 ${h} `;
            p += `L ${lW - fw - br} ${h} `;
            p += `C ${lW - fw - br * 0.45} ${h}, ${lW - fw} ${h - br * 0.45}, ${lW - fw} ${h - br} `;
            p += `L ${lW - fw} ${fh + tb} `;
            p += `C ${lW - fw} ${fh * 0.45 + tb}, ${lW - fw * 0.55} ${tb}, ${lW} ${tb} `;
            p += `L ${cX} ${tb} `;
            p += `C ${cX + fw * 0.55} ${tb}, ${cX + fw} ${fh * 0.45 + tb}, ${cX + fw} ${fh + tb} `;
            p += `L ${cX + fw} ${h - br} `;
            p += `C ${cX + fw} ${h - br * 0.45}, ${cX + fw + br * 0.45} ${h}, ${cX + fw + br} ${h} `;
            p += `L ${cX + cW - fw - br} ${h} `;
            p += `C ${cX + cW - fw - br * 0.45} ${h}, ${cX + cW - fw} ${h - br * 0.45}, ${cX + cW - fw} ${h - br} `;
            p += `L ${cX + cW - fw} ${fh + tb} `;
            p += `C ${cX + cW - fw} ${fh * 0.45 + tb}, ${cX + cW - fw * 0.55} ${tb}, ${cX + cW} ${tb} `;
            p += `L ${rX} ${tb} `;
            p += `C ${rX + fw * 0.55} ${tb}, ${rX + fw} ${fh * 0.45 + tb}, ${rX + fw} ${fh + tb} `;
            p += `L ${rX + fw} ${h - br} `;
            p += `C ${rX + fw} ${h - br * 0.45}, ${rX + fw + br * 0.45} ${h}, ${rX + fw + br} ${h} `;
            p += `L ${w} ${h} `;
            p += `L ${w} 0 `;
            p += `Z`;
            return p;
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.bg
                strokeColor: "transparent"
                strokeWidth: 0
                PathSvg { path: stage.barPath() }
            }
        }

        WheelHandler { onWheel: e => root.go(e.angleDelta.y > 0 ? "-1" : "+1") }

        // ---- левый наплыв: знак, воркспейсы, заголовок ----
        Row {
            id: leftRow
            x: stage.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            // знак: кольцо из точек, центр — красный, пока что-то пишет
            Item {
                id: mark
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                Ring { anchors.fill: parent; n: 16; dot: 3 }
                Rectangle {
                    anchors.centerIn: parent
                    width: 9
                    height: 9
                    radius: 4.5
                    color: Sys.live ? Theme.red : Theme.fg
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.markClicked() }
            }

            // воркспейсы: текущий вытягивается белой пилюлей, занятые 65%, пустые 22%
            Row {
                id: ws
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.count

                    Rectangle {
                        required property int index
                        readonly property int n: index + 1
                        readonly property bool occ: (Hyprland.workspaces.values.find(w => w.id === n)?.toplevels.values.length ?? 0) > 0
                        readonly property bool on: root.active === n
                        anchors.verticalCenter: parent.verticalCenter
                        width: on ? 24 : 8
                        height: 8
                        radius: 4
                        color: on ? Theme.fg : Theme.fade(Theme.fg, occ ? 0.65 : 0.22)
                        scale: wsHov.hovered && !on ? 1.2 : 1
                        HoverHandler { id: wsHov; cursorShape: Qt.PointingHandCursor }
                        Behavior on width { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                        Behavior on color { ColorAnimation { duration: Theme.t } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: root.go(parent.n) }
                    }
                }
            }

            // заголовок окна: приложение · название, обрезается по 200
            Lb {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 200)
                visible: Theme.state.barTitle && (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) > 0
                elide: Text.ElideRight
                text: root.top ? `${root.top.appId.split(".").pop()} · ${root.top.title}` : ""
                px: 10
                color: Theme.fade(Theme.fg, 0.45)
            }
        }

        // ---- центр: часы одной строкой (жирный Space Grotesk) и приглушённая дата.
        // Клик — календарь и фокус-таймер (cal/Cal) ----
        Row {
            id: clk
            x: stage.centerX + (stage.centerW - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            scale: clkHov.hovered ? 1.02 : 1
            TapHandler { onTapped: root.clockClicked() }
            HoverHandler { id: clkHov; cursorShape: Qt.PointingHandCursor }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.hh(clock.date) + ":" + Qt.formatTime(clock.date, "mm")
                font { family: Theme.ui; pixelSize: 18; weight: Font.Bold; letterSpacing: -0.4 }
                color: Theme.fg
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.locale("en_US").toString(clock.date, "ddd, d MMM")
                font { family: Theme.ui; pixelSize: 9; weight: Font.Medium }
                color: Theme.fade(Theme.fg, 0.4)
            }
        }

        // ---- правый наплыв: трей — Theme.state.bar по порядку (настройки, раздел BAR).
        // Раскладка, сеть, bluetooth, звук (колесо — громкость), уведомления, батарея: клик открывает быстрые настройки.
        // Режим питания и питание — свои клики ----
        Row {
            id: rightRow
            x: stage.width - stage.rightW + stage.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Repeater {
                    model: Theme.state.bar
                    Loader {
                        id: part
                        required property string modelData
                        readonly property bool quick: modelData !== "mode" && modelData !== "power"
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: root.parts[modelData] ?? null
                        visible: !!sourceComponent && (modelData !== "battery" || root.bat.isLaptopBattery)
                        TapHandler { enabled: part.quick; onTapped: root.trayClicked() }
                        HoverHandler { enabled: part.quick; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }

    readonly property var parts: ({ layout: layoutC, wifi: wifiC, bluetooth: btC, sound: soundC, notes: notesC, battery: batC, mode: modeC, power: powerC })
    Component { id: layoutC; Lb { text: Sys.layout; px: 10 } }
    Component {
        id: wifiC
        Icon {
            text: Networking.wifiEnabled ? "\u{F05A9}" : "\u{F05AA}"
            color: root.wifi?.connected ? Theme.fg : Theme.grey
        }
    }
    Component {
        id: btC
        Icon {
            text: Bluetooth.defaultAdapter?.enabled ? "\u{F00AF}" : "\u{F00B2}"
            color: Bluetooth.devices.values.some(d => d.connected) ? Theme.fg : Theme.grey
        }
    }
    Component {
        id: soundC
        Icon {
            text: Sys.muted ? "\u{F075F}" : "\u{F057E}"
            WheelHandler { onWheel: e => Sys.setVol(Sys.vol + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
        }
    }
    Component {
        id: notesC
        Icon {
            text: Theme.state.dnd ? "\u{F009B}" : "\u{F009A}"
            color: Notes.list.length ? Theme.fg : Theme.grey
        }
    }
    // батарея: молния на зарядке, заряд растёт слева направо, заливка дышит, пока заряжается
    Component {
        id: batC
        Row {
            id: batc
            HoverHandler { onHoveredChanged: { root.batHot = hovered; root.peek(batc); } Component.onDestruction: root.batHot = false }
            spacing: 6
            readonly property bool ac: !UPower.onBattery
            readonly property bool charging: root.bat.state === UPowerDeviceState.Charging
            // дыхание шагом 20 кадров/с, как шар в home/Back: анимация гнала бы бар на каждом vsync (120 Гц) все часы
            // зарядки. Косинус с периодом 2,2 с — те же два InOutSine по 1,1 с
            property real phase: 0
            readonly property real pulse: charging ? 0.675 + 0.325 * Math.cos(phase * Math.PI / 1.1) : 1
            Timer { running: batc.charging; interval: 50; repeat: true; onTriggered: batc.phase = (batc.phase + 0.05) % 2.2; onRunningChanged: batc.phase = 0 }
            Icon { visible: batc.ac; anchors.verticalCenter: parent.verticalCenter; text: "\u{F140B}"; font.pixelSize: 14 }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 14
                radius: 7
                color: "transparent"
                border { width: 1.5; color: Theme.grey }
                Rectangle {
                    x: 3
                    height: parent.height - 6
                    width: (parent.width - 6) * root.bat.percentage
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 4
                    color: root.batLow ? Theme.red : Theme.fg
                    opacity: batc.pulse
                }
            }
            Lb { anchors.verticalCenter: parent.verticalCenter; text: Math.round(root.bat.percentage * 100); px: 10 }
        }
    }
    // режим питания засечками (Rules.modes): ultra — одна, performance — все; клик — следующий,
    // наведение (и на батарею) — карточка с выбором
    Component {
        id: modeC
        Item {
            id: ticks
            width: 40
            height: 22
            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: Rules.modeCount
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 3
                        height: 5 + index * 3
                        radius: 1.5
                        color: index <= Rules.mode ? Theme.fg : Theme.s3
                    }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: { root.tickHot = hovered; root.peek(ticks); } Component.onDestruction: root.tickHot = false }
            TapHandler { onTapped: Rules.setMode((Rules.mode + 1) % Rules.modeCount) }
        }
    }
    Component {
        id: powerC
        Icon {
            text: "\u{F0425}"
            color: pwr.hovered ? Theme.fg : Theme.grey
            HoverHandler { id: pwr; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.powerClicked() }
        }
    }

    // ---- батарея и режим питания: навёл на батарею или засечки — карточка под баром, по центру того,
    // на что навели. Заряд Doto, статус, шкала; ниже режимы кругами с засечками — клик выбирает, под курсором —
    // что он делает. Ушёл и с бара, и с карточки — гаснет ----
    property bool batHot: false
    property bool tickHot: false
    readonly property bool powHot: batHot || tickHot || popHov.hovered
    readonly property bool batLow: UPower.onBattery && root.bat.percentage < 0.15
    // карточка встаёт по центру того, на что навели; пока видна — не прыгает
    property real popX: 0
    function peek(it) { if (!pop.visible) popX = it.mapToItem(stage, it.width / 2, 0).x; }
    property bool powOpen: false
    property int powPeek: -1
    onPowHotChanged: powHot ? powOpenT.restart() : powCloseT.restart()
    Timer { id: powOpenT; interval: 180; onTriggered: if (root.powHot) root.powOpen = true }
    Timer { id: powCloseT; interval: 300; onTriggered: if (!root.powHot) root.powOpen = false }
    function hm(sec) { const m = Math.round(sec / 60); return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} m` : `${m} m`; }
    readonly property string batState: root.bat.state === UPowerDeviceState.Charging
        ? "charging" + (root.bat.timeToFull ? ` · full in ${hm(root.bat.timeToFull)}` : "")
        : !UPower.onBattery ? "on ac · full"
        : "on battery" + (root.bat.timeToEmpty ? ` · ${hm(root.bat.timeToEmpty)} left` : "")

    PopupWindow {
        id: pop
        property real t: root.powOpen ? 1 : 0
        Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        visible: t > 0
        // под баром, по центру того, на что навели; растёт вниз
        anchor.item: stage
        anchor.rect: Qt.rect(root.popX - (pop.implicitWidth / Theme.s) / 2, stage.height + 8, 1, 1)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        implicitWidth: Math.ceil(440 * Theme.s)
        implicitHeight: Math.ceil(card.height * Theme.s)
        color: "transparent"

        Stage {
            Rectangle {
                id: card
                width: 440
                height: body.height + 52
                radius: 36
                color: Theme.bg
                border { width: 1; color: Theme.s2 }
                opacity: pop.t
                transform: Translate { y: -16 * (1 - pop.t) }
                HoverHandler { id: popHov }

                Column {
                    id: body
                    x: 26
                    y: 26
                    width: parent.width - 52
                    spacing: 18

                    Row {
                        spacing: 14
                        Num { text: Math.round(root.bat.percentage * 100); font.pixelSize: 72 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Lb { text: "% battery"; color: Theme.fg }
                            Lb { text: root.batState }
                        }
                    }
                    Seg { width: parent.width; height: 6; n: 24; f: root.bat.percentage; on: root.batLow ? Theme.red : Theme.fg }

                    Lb { topPadding: 6; text: "power mode" }
                    Row {
                        spacing: (body.width - Rules.modeCount * 80) / Math.max(1, Rules.modeCount - 1)
                        Repeater {
                            model: Rules.modeCount
                            Column {
                                id: mo
                                required property int index
                                readonly property bool on: Rules.mode === index
                                spacing: 10
                                Rectangle {
                                    width: 80
                                    height: 80
                                    radius: 40
                                    color: mo.on ? Theme.fg : moHov.hovered ? Theme.s3 : Theme.s2
                                    Behavior on color { ColorAnimation { duration: Theme.t } }
                                    // засечки: сколько горит — такая сила
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                required property int index
                                                anchors.bottom: parent.bottom
                                                width: 5
                                                height: 8 + index * 6
                                                radius: 2.5
                                                color: index <= mo.index ? (mo.on ? Theme.ink : Theme.fg) : (mo.on ? Theme.mute : Theme.s3)
                                            }
                                        }
                                    }
                                    HoverHandler {
                                        id: moHov
                                        cursorShape: Qt.PointingHandCursor
                                        onHoveredChanged: if (hovered) root.powPeek = mo.index; else if (root.powPeek === mo.index) root.powPeek = -1
                                    }
                                    TapHandler { onTapped: Rules.setMode(mo.index) }
                                }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: mo.index === 3 ? "max" : Rules.modes[mo.index].name; color: mo.on ? Theme.fg : Theme.grey }
                            }
                        }
                    }
                    Lb {
                        readonly property int i: root.powPeek >= 0 ? root.powPeek : Rules.mode
                        width: parent.width
                        elide: Text.ElideRight
                        text: `${Rules.modes[i].what} · ${i === 0 ? Rules.rates[0] : Rules.refreshHz} hz`
                    }
                }
            }
        }
    }
}
