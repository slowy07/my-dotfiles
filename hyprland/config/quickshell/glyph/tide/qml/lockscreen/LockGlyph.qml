import QtQuick

Image {
    id: root
    property string name: "lock"
    property color ink: "#f5f5f7"
    property bool filled: false
    sourceSize: Qt.size(width * 2, height * 2)
    fillMode: Image.PreserveAspectFit
    source: {
        const paths = {
            lock: '<rect x="5" y="10" width="14" height="11" rx="3"/><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3"/>',
            arrow: '<path d="M5 12h14m-6-6 6 6-6 6"/>',
            previous: '<path d="m11 5-9 7 9 7Zm11 0-9 7 9 7Z"/>',
            next: '<path d="m2 5 9 7-9 7Zm11 0 9 7-9 7Z"/>',
            play: '<path d="m8 5 11 7-11 7Z"/>',
            pause: '<rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/>',
            heart: '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0l-1 1-1-1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z"/>',
            music: '<path d="M9 17V5l12-2v12M9 9l12-2"/><ellipse cx="6" cy="18" rx="3" ry="3"/><ellipse cx="18" cy="16" rx="3" ry="3"/>',
            sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/>',
            cloud: '<path d="M6 19a5 5 0 1 1 0-10 7 7 0 0 1 13-1 5.5 5.5 0 0 1-1 11Z"/>',
            rain: '<path d="M6 15a4 4 0 1 1 0-8 6 6 0 0 1 11-1 4.5 4.5 0 0 1 1 9M8 18l-1 3m6-3-1 3m6-3-1 3"/>',
            snow: '<path d="M12 2v20M3.3 7l17.4 10M3.3 17 20.7 7M9 4l3 3 3-3M9 20l3-3 3 3"/>',
            battery: '<rect x="2" y="6" width="18" height="12" rx="3"/><path d="M23 10v4M6 10v4m4-4v4m4-4v4"/>',
            bolt: '<path d="m13 2-9 12h7l-1 8 10-13h-7Z"/>',
            user: '<circle cx="12" cy="8" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/>',
            check: '<path d="m5 12 4 4L19 6"/>',
            eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>'
        };
        return "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="'
            + (filled ? ink : 'none') + '" stroke="' + ink + '" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'
            + (paths[name] || paths.lock) + '</svg>');
    }
}
