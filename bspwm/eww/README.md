# eww Bar (dock)

Bottom-centre dock for bspwm. Ported/simplified from siduck/stow_dots' eww bar, used on
the `hela` rice of the gh0stzk bspwm dots. Runs on one daemon with two windows:

- `dock`  — full bar on the primary monitor: workspaces + taskbar + system modules.
- `dock2` — small strip on a second monitor showing only that monitor's workspaces.

## Structure

```
./
├── eww.yuck            window definitions (dock, dock2)
├── eww.scss            global css root + @import chain
├── colors.scss         color palette ($bg $fg $blue $green $red ...)
└── bar/
    ├── bar.yuck        defwindow dock + dock2 (_docks_)
    ├── bar.scss        all bar styling (imports colors.scss)
    ├── src/
    │   ├── left.yuck   distro icon (opens app menu), workspaces, taskbar
    │   ├── middle.yuck clock
    │   ├── right.yuck  updates, temp, battery, ram, cpu, volume, wifi+netspeed, power, systray
    │   └── workspaces.yuck  per-monitor workspace listeners (dock + dock2)
    └── scripts/
        ├── WorkSpaces   emits workspace buttons for one monitor
        ├── netspeed.sh  eww poll: current down/up speed
        ├── utils.sh     taskbar click / pinning / volume & netspeed toggle dispatch
        └── taskbar.sh   taskbar poll (window icons + states)
```

## Run

```sh
eww -c ~/.config/bspwm/eww daemon
eww -c ~/.config/bspwm/eww open dock --screen 0   # primary
eww -c ~/.config/bspwm/eww open dock2             # iff 2 monitors exist
```

In the rice (rices/hela/Bar.bash) the daemon is already started/opened and the windows are
re-mapped on start. Fullscreen auto-hide is handled by `bin/HideBar` (X-layer toggle, not
a daemon close/reopen).

## Tweak guide

### Colors
Edit `colors.scss`. Every module in `bar.scss` references the `$*` variables (some via
`mix()`), so re-coloring the whole bar is one file.

### Fonts
`bar.scss` `.zuup` sets the bar font family (currently `JetbrainsMono Nerd Font Mono
SemiBold`). Glyph icons throughout need a Nerd Font; change them by editing the literal
glyphs in the widgets (left/right.yuck). Keep sub-elements (`.netspeed`, `.workspaces-mon`)
on the same family — they declare it explicitly.

### Position / size / reserve
`bar.yuck` defwindow:
- `:width "90%"` — bar width (dock; dock2 is auto-sized).
- `:anchor "bottom center"`, `:y "-0.5%"` — bottom-centre placement.
- `:reserve (struts :side "bottom" :distance "63px")` — space reserved for the bar.

The window padding after the struts is `BOTTOM_PADDING` in
`rices/<rice>/theme-config.bash` — keep it matching the struts distance so windows don't
hide behind the bar.

### Monitoring a different display
`bspc monitor <name> -d 1 2 3 4` defines a monitor's desktop set (this REPLACES the current
list). The split in this config is HDMI-A-0 → 1-4, eDP → 5-8. The dock assigns a monitor
with the `:monitor` attr and each `workspaces_mon` widget takes a `:monitor` string; the
`WorkSpaces` script only renders that monitor's desktops (focused/occupied/empty).

### Workspaces appearance
`bar.scss`:
- `.workspaces-mon` — container (bg, padding, font).
- `.workspace-focused` — active desktop (green foreground).
- `.workspace-occupied` / `.workspace-empty` — other states (+hover).
Adjust gaps between desktop buttons in the `WorkSpaces` script output or the button
margins in `bar.scss`.

### Modules
Add/remove entries in the `right` widget list in `bar/src/right.yuck` (counter modules use
eww's built-in magic vars `EWW_CPU`, `EWW_RAM`, `EWW_TEMPS`, `EWW_BATTERY`, `EWW_NET`).
- **Netspeed**: wifi icon click toggles a live `↓ / ↑` readout (`show_netspeed` var +
  `netspeed` defpoll → `scripts/netspeed.sh`, toggled via `utils.sh toggle_netspeed`).
- **Updates**: polls `~/.cache/Updates.txt` (written by `bin/Updates`).
- **Taskbar**: `scripts/taskbar.sh` + `utils.sh` handle per-window icons, pinning, and the
  multi-window menu.

### onclicks and IPC
Buttons shell out to scripts. Two rules that keep clicks working:
- Scripts that talk back to the daemon must pass the config dir, e.g.
  `eww -c $HOME/.config/bspwm/eww update <var>=<val>` (bare `eww update` targets
  `~/.config/eww` and fails). Do it via `utils.sh` helpers like volume/netspeed toggles.
- `~/.config/bspwm/bin` scripts call siblings by bare name, so the executing env needs
  `bspwm/bin` on `PATH`. The distro icon inline-exports it:

```
:onclick "PATH=\"$HOME/.config/bspwm/bin:$PATH\" OpenApps --menu"
```

## External dependencies (not in this dir)

| Thing | Where | Used for |
|------|------|----------|
| `bin/OpenApps`, `bin/RofiLauncher`, rofi themes | `~/.config/bspwm/bin`, `~/config/rofi-themes` | distro-icon app menu |
| `bin/HideBar` | `~/.config/bspwm/bin` | fullscreen show/hide (X-layer) |
| `bin/Updates` | `~/.config/bspwm/bin` | writes `~/.cache/Updates.txt` |
| `BOTTOM_PADDING` | `rices/hela/theme-config.bash` | window padding matching struts |
| SNI systray | eww daemon (owns `org.kde.StatusNotifierWatcher`) | system tray in `right` |