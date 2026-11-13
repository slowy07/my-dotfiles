# Tide Island vendored copy

- Upstream: https://github.com/enhaoswen/Tide-island
- Commit: fbc165d7c4e823ab6f6946f472a87e0ffe79acbf (2026-10-31)
- License: GPL-3.0, see `LICENSE`
- Upstream repository is unmaintained and has moved to Tide-Island-New. This
  copy follows the old tree on purpose.

## Local changes

- `StyleTokensBackend` reads theme colors from
  `$XDG_STATE_HOME/rice/tide-colors.json` and reloads on change.
- Removed the standalone controller, app, lyrics client, tests, and scripts.
- Removed `SpotifyBridge` and the Qt WebSockets dependency.
- Added a trimmed Glyph controller `TideIsland.qml`.
- Removed automatic workspace, volume, brightness, Bluetooth, and swipe
  triggers.
- Moved notification history to one shared model in the controller.
- The notification capsule does not replace an open notification center,
  calendar, control center, player, or file shelf; history updates live.
- The notification center height follows the number of visible cards, from one
  to three.
- Island geometry defaults to 170 x 29, and the exclusive zone is forced to
  `-1` so the bar keeps its own reserved area.
- Replaced hardcoded colors in the clock, calendar, notification, history,
  and player surfaces with `StyleTokens`.

## Build

```sh
cmake -S . -B "${XDG_CACHE_HOME:-$HOME/.cache}/glyph/tide-build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "${XDG_CACHE_HOME:-$HOME/.cache}/glyph/tide-build"
sudo cmake --install "${XDG_CACHE_HOME:-$HOME/.cache}/glyph/tide-build"
```

The plugin installs to `/usr/lib/qt6/qml/IslandBackend`. Rebuild after a Qt
ABI change.
