pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// cava runs in the background while someone watches (active): 8 mono bars 0…1, from bass to treble (the count is in cava.conf)
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
