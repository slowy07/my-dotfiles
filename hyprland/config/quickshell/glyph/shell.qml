import QtQuick
import Quickshell
import Quickshell.Hyprland
import "bar"
import "buds"
import "charms"
import "clip"
import "deck"
import "glyph"
import "home"
import "launcher"
import "power"
import "prefs"
import "quick"
import "settings"
import "shot"
import "tide"
import "vpn"
import "wall"

// glyph: a rice in the spirit of nothing os. Home on the wallpaper, bar, launcher, quick settings,
// Glyph strips at the edges instead of OSD, notification island, power menu, settings, deck (bottom dashboard), clipboard, charms (emoji and symbols), screenshots, vpn, wallpaper. Lock is a separate process (lock.qml).
// Switched from demonshot via `rice switch` / the Rice app; hypr binds are shared (shell:*), each shell takes its own
ShellRoot {
    id: shell

    Launcher { id: launcher }
    Quick { id: quick; onPowerRequested: power.open(); onSettingsRequested: prefs.open() }
    Power { id: power }
    Prefs { id: prefs; onWallRequested: walls.open() }
    Glyph { id: glyph }
    TideIsland { id: tideIsland }
    Buds {}
    Clip { id: clip }
    Charms { id: charms }
    Deck { id: deck }
    Shot { id: shot }
    Vpn { id: vpn }
    Walls { id: walls }

    Variants {
        model: Quickshell.screens
        Scope {
            id: s
            required property var modelData
            Back { screen: s.modelData }
            Home { screen: s.modelData }
            Hot { screen: s.modelData; onTriggered: quick.peek() }
            Bar {
                screen: s.modelData
                onMarkClicked: launcher.toggle()
                onTrayClicked: quick.toggle()
                onPowerClicked: power.visible ? power.close() : power.open()
            }
        }
    }

    // hypr as in demonshot: its Rules (settings/Rules.qml, the same ~/.config/demonshot/rules.json) set monitor, input,
    // motion, night light and hypridle; on top Theme.apply sets its own border colors, rounding and kitty. It is also called on theme change
    Component.onCompleted: {
        hypr();
        Rules.night();
        Rules.idle();
    }
    // what lives in the hypr config. It rereads it itself: save any hypr file (links are live, both git pull and branch
    // changes), hyprctl reload, and it restores variables.lua defaults: demonshot borders, monitor, input, animations. We apply
    // ours again. hyprctl eval configreloaded is not sent, so there is no loop. Night light and hypridle are separate processes, reload does not touch them
    function hypr() {
        Rules.monitor();
        Rules.input();
        Rules.motion();
        Theme.apply();
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "configreloaded") shell.hypr(); }
    }
    Connections {
        target: Theme
        function onLightChanged() { Theme.apply(); }
    }
    Connections {
        target: Theme.state
        function onRoundingChanged() { Theme.apply(); }
    }
    Connections {
        target: Theme.state
        function onSchemeChanged() { Theme.apply(); }
    }
    // ultra mode enables/disables blur and shadows over the settings; windows must be repainted (refresh rate and motion are set by Rules.setMode).
    // Game mode does the same and also animations
    Connections {
        target: Rules.store
        function onUltraChanged() { Theme.apply(); }
        function onGameChanged() { Rules.motion(); Theme.apply(); }
    }
    // Glyph power, network and focus events also appear as a capsule in the
    // island, without entering the notification history
    Connections {
        target: glyph
        function onEventHappened(app, summary, body) { tideIsland.showTransient(app, summary, body); }
    }

    // Super tap opens the launcher on release; any Super+<key> along the way sends interrupt, and the launcher does not open
    property bool interrupted: false
    Shortcut {
        name: "launcher"
        description: "лаунчер (тап Super)"
        onReleased: {
            if (!shell.interrupted) launcher.toggle();
            shell.interrupted = false;
        }
    }
    Shortcut { name: "launcherArm"; description: "нажатие Super — сброс interrupt"; onPressed: shell.interrupted = false }
    Shortcut { name: "launcherInterrupt"; description: "Super+<key> — do not open launcher"; onPressed: shell.interrupted = true }
    // Super+Space (altar in demonshot) is deck, the bottom dashboard; the launcher is already on Super tap
    Shortcut { name: "altar"; description: "deck: dashboard at bottom"; onPressed: deck.toggle() }
    Shortcut { name: "quick"; description: "quick settings"; onPressed: quick.toggle() }
    Shortcut { name: "ward"; description: "quick settings"; onPressed: quick.toggle() } // Super+N in demonshot uses the same toggles
    Shortcut { name: "settings"; description: "settings"; onPressed: prefs.toggle() }
    Shortcut { name: "power"; description: "power menu"; onPressed: power.visible ? power.close() : power.open() }
    Shortcut { name: "shot"; description: "screenshot"; onPressed: shot.open() }
    Shortcut { name: "pact"; description: "vpn: clash verge"; onPressed: vpn.toggle() }
    Shortcut { name: "clip"; description: "clipboard"; onPressed: clip.toggle() }
    Shortcut { name: "charms"; description: "emoji, kaomoji, symbols"; onPressed: charms.toggle() }
    Shortcut { name: "wall"; description: "wallpaper"; onPressed: walls.toggle() }
    Shortcut { name: "game"; description: "game mode"; onPressed: Rules.store.game = !Rules.store.game }

    component Shortcut: GlobalShortcut { appid: "shell" }
}
