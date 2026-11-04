pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// cava в фоне, пока кто-то смотрит (active): 8 полос моно 0…1, от баса к верхам (число — в cava.conf)
Singleton {
    id: root

    property bool active: false
    property var bars: Array(8).fill(0)

    Process {
        running: root.active
        command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => root.bars = line.split(";").filter(s => s !== "").map(v => v / 100)
        }
        onRunningChanged: if (!running) root.bars = Array(8).fill(0)
    }
}
