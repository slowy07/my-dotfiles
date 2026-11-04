pragma Singleton

import QtQuick
import Quickshell

// фокус-таймер: крутит панель часов (cal/Cal), пока идёт — Glyph заливает нижнюю полосу. Считает до end, а не тиками —
// не уплывает, если тик опоздал. ponytail: живёт в памяти, перезапуск шелла сбрасывает; переживать — в Theme.state
Singleton {
    id: root

    property int minutes: 25
    property bool running: false
    property real end: 0
    property real rest: minutes * 60000 // остаток на паузе
    property real now: Date.now()
    readonly property real left: running ? Math.max(0, end - now) : rest
    readonly property real f: 1 - left / (minutes * 60000)
    readonly property bool paused: !running && rest < minutes * 60000
    signal done

    function set(m) { minutes = m; reset(); }
    function reset() { running = false; rest = minutes * 60000; }
    function toggle() {
        if (running) { rest = left; running = false; return; }
        now = Date.now();
        end = now + rest;
        running = true;
    }
    function mmss(ms) { const s = Math.ceil(ms / 1000); return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`; }

    Timer {
        running: root.running
        interval: 1000
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (root.left > 0) return;
            root.reset();
            root.done();
        }
    }
}
