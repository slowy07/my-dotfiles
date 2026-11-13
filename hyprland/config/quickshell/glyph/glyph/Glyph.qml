import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components

// Glyph: screen edges as LEDs on the back, instead of OSDs and popups in the middle of the screen.
// On top, a flash for power and network events (red for critical); on the right, volume/brightness bottom to top;
// on the bottom, progress of long tasks (notifications with a hint value) or the focus timer (Focus). They fade after 3 s
Scope {
    id: root

    // ---- right: volume and brightness ----
    property string kind: "vol"
    property real value: 0
    property bool armed: false // do not show initial values at startup
    Timer { running: true; interval: 1500; onTriggered: root.armed = true }
    function level(k, v) {
        if (!armed || !Theme.state.edges) return;
        kind = k;
        value = v;
        side.shown = true;
        sideT.restart();
    }
    Connections {
        target: Sys.sink?.audio ?? null
        function onVolumeChanged() { root.level("vol", Sys.muted ? 0 : Sys.vol); }
        function onMutedChanged() { root.level("vol", Sys.muted ? 0 : Sys.vol); }
    }
    Connections {
        target: Sys
        function onBriChanged() { root.level("bri", Sys.bri); }
    }
    Timer { id: sideT; interval: 3000; onTriggered: side.shown = false }

    // ---- top: power and network events flash the strip ----
    property var note: null // latest, for the flash
    signal eventHappened(string app, string summary, string body)
    // card for the flash: c is { crit }, the top strip only needs the urgency
    function push(c) {
        root.note = { urgency: c.crit ? NotificationUrgency.Critical : NotificationUrgency.Normal };
        root.eventHappened(c.app ?? "", c.summary ?? "", c.body ?? "");
        noteT.restart();
    }
    // The Tide island is the notification presenter; the top edge stays for
    // power and network events only.

    // ---- power: charger plugged/unplugged, charged, discharging (warn at 15%, red at 5%). As a card in the island,
    // bypassing notification history. armed prevents startup events ----
    readonly property var bat: UPower.displayDevice
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property int pct: Math.round((bat?.percentage ?? 0) * 100)
    property int warned: 100
    function hm(s) { const m = Math.round(s / 60); return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} m` : `${m} m`; }
    function power(summary, glyph, crit, time) {
        if (root.armed && root.bat?.isLaptopBattery) root.push({ app: "power", summary, body: `${root.pct}%` + (time ? ` · ${time}` : ""), glyph, crit: !!crit });
    }
    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.warned = 100;
            if (UPower.onBattery) root.power("On battery", "\u{F0079}", false, root.bat.timeToEmpty ? `${root.hm(root.bat.timeToEmpty)} left` : "");
            else root.power("Charging", "\u{F0084}", false, root.bat.timeToFull ? `full in ${root.hm(root.bat.timeToFull)}` : "");
        }
    }
    Connections {
        target: root.bat
        function onStateChanged() { if (root.bat.state === UPowerDeviceState.FullyCharged && !UPower.onBattery) root.power("Fully charged", "\u{F0079}"); }
        function onPercentageChanged() {
            if (!UPower.onBattery) return;
            if (root.pct <= 5 && root.warned > 5) { root.warned = 5; root.power("Battery critical", "\u{F0083}", true, "plug in now"); }
            else if (root.pct <= 15 && root.warned > 15) { root.warned = 15; root.power("Battery low", "\u{F0083}", false, "plug in soon"); }
        }
    }
    // network: a Wi-Fi device that was connected and is no longer. armed prevents startup events
    Connections {
        target: root.wifi
        function onConnectedChanged() {
            if (root.armed && root.wifi && !root.wifi.connected)
                root.push({ app: "network", summary: "Wi-Fi disconnected", body: "", glyph: "\u{F05AA}" });
        }
    }
    Timer { id: noteT; interval: 3000; onTriggered: root.note = null }
    readonly property bool crit: note?.urgency === NotificationUrgency.Critical

    Edge {
        id: top
        shown: !!root.note && Theme.state.edges
        anchors.top: true
        implicitWidth: Math.ceil(640 * Theme.s)
        implicitHeight: Math.ceil(30 * Theme.s)
        Seg {
            x: 20
            y: 4
            width: 600
            height: 4
            n: 12
            f: 1
            on: root.crit ? Theme.red : Theme.fg
            layer.enabled: true
            layer.effect: Glow {}
            SequentialAnimation on opacity {
                running: top.shown
                loops: Animation.Infinite
                NumberAnimation { from: 0.15; to: 1; duration: 720; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.15; duration: 1680; easing.type: Easing.InOutSine }
            }
        }
    }

    // ---- right ----
    Edge {
        id: side
        anchors.right: true
        implicitWidth: Math.ceil(160 * Theme.s)
        implicitHeight: Math.ceil(520 * Theme.s)
        Lit {
            x: 160 - 5 - 5
            y: 10
            width: 5
            height: 500
            n: 20
            vertical: true
            f: root.value
        }
        Tag {
            vertical: true // for a vertical strip the capsule is vertical too: icon above the number
            anchors { right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
            Icon { text: root.kind === "bri" ? "\u{F00E0}" : Sys.muted ? "\u{F075F}" : "\u{F057E}" }
            Num { text: Math.round(root.value * 100); font.pixelSize: 30 }
        }
    }

    // ---- bottom: task progress; without one, a running focus timer (a single strip, no capsule: it stays for tens of minutes) ----
    // The focus start and done events also add a card to the island.
    readonly property var task: Notes.task
    readonly property real progress: task ? Math.max(0, Math.min(100, task.hints.value ?? 0)) / 100 : Focus.f
    Connections {
        target: Focus
        function onRunningChanged() {
            if (Focus.running) root.push({ app: "focus", summary: "Focus started", body: `${Focus.minutes} min`, glyph: "\u{F13AB}" });
        }
        function onDone() { root.push({ app: "focus", summary: "Focus done", body: `${Focus.minutes} min`, glyph: "\u{F13AB}" }); }
    }
    Edge {
        shown: (!!root.task || Focus.running) && Theme.state.edges
        anchors.bottom: true
        implicitWidth: Math.ceil(1100 * Theme.s)
        implicitHeight: Math.ceil(110 * Theme.s)
        Lit {
            x: 10
            y: 110 - 5 - 5
            width: 1080
            height: 5
            n: 40
            f: root.progress
        }
        Tag {
            visible: !!root.task
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
            Icon { text: "\u{F01DA}" }
            Lb { text: root.task?.summary ?? ""; color: Theme.fg }
            Num { text: Math.round(root.progress * 100) + "%"; font.pixelSize: 26 }
        }
    }

    // edge strip: mouse-transparent, drawn in layout pixels
    component Edge: PanelWindow {
        property bool shown
        default property alias content: st.data
        visible: shown
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glyph-edge"
        Stage { id: st }
    }
    // value capsule next to the strip; vertical stacks the content
    component Tag: Rectangle {
        default property alias content: box.data
        property bool vertical
        width: vertical ? Math.max(52, box.width + 24) : box.width + 32
        height: vertical ? box.height + 36 : 52
        radius: Math.min(width, height) / 2
        color: Theme.s1
        border { width: 1; color: Theme.s2 }
        Grid {
            id: box
            anchors.centerIn: parent
            columns: parent.vertical ? 1 : 99
            spacing: parent.vertical ? 10 : 12
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
        }
    }
    // glow of lit segments is the only "shadow" in the entire shell
    component Glow: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.glow
        shadowBlur: 0.7
        blurMax: 20
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }
}
