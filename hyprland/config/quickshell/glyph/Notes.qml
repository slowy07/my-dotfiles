pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// уведомления: новое — остров сверху и вспышка Glyph, история — карточками в быстрых настройках
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values
    property var times: ({}) // id → когда пришло: у Notification своего времени нет
    signal arrived(var n)

    // прогресс долгих задач — hint value (notify-send -h int:value:64 …): нижняя полоса Glyph
    readonly property var task: list.slice().reverse().find(n => n.hints?.value !== undefined) ?? null

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        keepOnReload: false
        onNotification: n => {
            n.tracked = true;
            root.times = Object.assign({}, root.times, { [n.id]: Date.now() });
            if (!Theme.state.dnd || n.urgency === NotificationUrgency.Critical) root.arrived(n);
        }
    }

    function clear() { for (const n of list.slice()) n.dismiss(); }
    function ago(n, now) {
        const m = Math.floor((now - (times[n.id] ?? now)) / 60000);
        return m < 1 ? "now" : m < 60 ? `${m} min` : `${Math.floor(m / 60)} h`;
    }

    // счёт — в состояние: лок пишет «3 notifications»
    onListChanged: if (Theme.state.unread !== list.length) Theme.state.unread = list.length
}
