pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// notifications: the server owns the bus, every arrival feeds the Tide island,
// and the tracked list feeds the Glyph bar and quick settings
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values
    property var times: ({}) // id to arrival time; a Notification has no time of its own
    signal received(var n)

    // progress of long tasks via hint value (notify-send -h int:value:64 ...): the bottom Glyph strip
    readonly property var task: list.slice().reverse().find(n => n.hints?.value !== undefined) ?? null

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        keepOnReload: false
        onNotification: n => {
            n.tracked = true;
            root.times = Object.assign({}, root.times, { [n.id]: Date.now() });
            root.received(n);
        }
    }

    function clear() { for (const n of list.slice()) n.dismiss(); }
    function ago(n, now) {
        const m = Math.floor((now - (times[n.id] ?? now)) / 60000);
        return m < 1 ? "now" : m < 60 ? `${m} min` : `${Math.floor(m / 60)} h`;
    }

    // count into state: the lock writes "3 notifications"
    onListChanged: if (Theme.state.unread !== list.length) Theme.state.unread = list.length
}
