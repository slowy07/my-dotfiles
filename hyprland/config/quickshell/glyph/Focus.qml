pragma Singleton

import QtQuick
import Quickshell

// focus / break (pomodoro) timer: driven by the calendar panel (cal/Cal). Alternates focus <-> break
// when a timer runs to zero, keeping the cycle going. Counts to end, not by ticks, so it does not drift
// if a tick is late. Lives in memory; a shell restart resets it.
// focusMinutes / breakMinutes are custom from the calendar UI.
Singleton {
    id: root

    property int focusMinutes: 25
    property int breakMinutes: 5
    property bool isBreak: false
    property bool running: false
    property real end: 0
    property real rest: 0 // remaining while paused (ms of current mode)
    property real now: Date.now()
    signal done
    signal modeChanged(string mode)

    // total ms of the current mode
    readonly property int modeMs: isBreak ? breakMinutes * 60000 : focusMinutes * 60000
    readonly property real left: running ? Math.max(0, end - now) : rest
    readonly property real f: modeMs > 0 ? 1 - left / modeMs : 0
    readonly property bool paused: !running && rest < modeMs && rest > 0

    Component.onCompleted: root.rest = root.modeMs

    function set(m) { setFocus(m); }
    function setFocus(m) { focusMinutes = m; if (!isBreak) reset(); }
    function setBreak(m) { breakMinutes = m; if (isBreak) reset(); }
    function reset() { running = false; rest = modeMs; }
    function toggle() {
        if (running) { rest = left; running = false; return; }
        now = Date.now();
        end = now + rest;
        running = true;
    }
    // switch to the other mode (focus <-> break) and restart the count for it
    function switchMode() {
        isBreak = !isBreak;
        running = false;
        rest = modeMs;
        modeChanged(isBreak ? "break" : "focus");
    }
    function mmss(ms) { const s = Math.ceil(ms / 1000); return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`; }

    Timer {
        running: root.running
        interval: 1000
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (root.left > 0) return;
            // cycle to the other mode and keep running (pomodoro loop)
            root.isBreak = !root.isBreak;
            root.rest = root.modeMs;
            root.end = root.now + root.rest;
            root.done();
        }
    }
}
