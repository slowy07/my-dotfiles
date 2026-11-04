# Hyprland configuration

This directory contains the Hyprland desktop configuration used on this system. It covers the window manager, the [Glyph](https://github.com/Nebelung-cloud/glyph-rice) Quickshell shell, the terminal colors, the Qt theme, and the fonts required by the interface.

## Contents

| Path | Purpose |
|---|---|
| `config/hypr` | Hyprland configuration written in Lua. Includes window rules, key bindings, input, decorations, animations, and color scheme tables. |
| `config/quickshell/glyph` | Glyph Quickshell shell. Provides the bar, launcher, settings menu, lock screen, notifications, and the color scheme picker. |
| `config/quickshell/rice` | Shell launcher script used by Hyprland to start the selected Quickshell shell. |
| `config/kitty` | kitty terminal configuration. Contains the font, padding, tab style, animations, and key maps. Ends with an include for the generated color file. |
| `config/demonshot` | Runtime configuration written by the shell. Contains the generated kitty palette, hypridle configuration, and shell rules. |
| `config/qtengine` | Qt platform theme configuration. |
| `.local/share/fonts/glyph` | Doto, Space Grotesk, and Space Mono font files. |

## Requirements

Arch Linux is the supported platform. The configuration expects the following packages.

| Component | Packages |
|---|---|
| Session | `hyprland`, `hypridle`, `hyprsunset`, `hyprpicker`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` |
| Shell | `quickshell`, `polkit-gnome`, `gnome-keyring`, `geoclue`, `upower`, `jq`, `curl`, `python`, `libqalculate` |
| Audio and network | `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `wireplumber`, `networkmanager`, `bluez`, `bluez-utils`, `power-profiles-daemon` |
| Utilities | `brightnessctl`, `playerctl`, `wl-clipboard`, `cliphist`, `grim`, `slurp`, `swappy`, `imagemagick`, `libvips`, `gpu-screen-recorder`, `ydotool`, `libnotify`, `trash-cli` |
| Terminal | `kitty`, `fish`, `starship`, `fastfetch`, `btop`, `cava`, `eza`, `zoxide`, `direnv` |
| Appearance | `papirus-icon-theme`, `adw-gtk-theme`, `ttf-jetbrains-mono-nerd`, `noto-fonts`, `noto-fonts-cjk`, `noto-fonts-emoji`, `bibata-cursor-theme-bin` |
| Optional | `qtengine`, `darkly-bin`, `clash-verge-rev`, `telegram-desktop`, `spotify-launcher` |

`quickshell` requires Qt 6.9 or newer. The Hyprland configuration uses the Lua configuration interface and requires Hyprland 0.56 or newer.

Several packages are available only from the AUR: `qtengine`, `darkly-bin`, `bibata-cursor-theme-bin`, `clash-verge-rev-bin`, and `zen-browser-bin`.

## Installation

1. Clone the repository and select the `hyprland` branch.

   ```sh
   git clone --branch hyprland https://github.com/slowy07/my-dotfiles.git
   cd my-dotfiles
   ```

2. Move the existing configuration to a timestamped backup directory.

   ```sh
   backup="$HOME/.dots-backup-$(date +%F_%H-%M-%S)"
   mkdir -p "$backup/.config"
   for path in hypr kitty quickshell qtengine demonshot; do
       if [ -e "$HOME/.config/$path" ] || [ -L "$HOME/.config/$path" ]; then
           mv "$HOME/.config/$path" "$backup/.config/"
       fi
   done
   ```

3. Copy the configuration into the home directory.

   ```sh
   mkdir -p "$HOME/.config"
   cp -a hyprland/config/. "$HOME/.config/"
   ```

4. Install the fonts and refresh the font cache.

   ```sh
   mkdir -p "$HOME/.local/share/fonts"
   rm -rf "$HOME/.local/share/fonts/glyph"
   cp -a hyprland/.local/share/fonts/glyph "$HOME/.local/share/fonts/"
   fc-cache -f
   ```

5. Initialize the shell state. The Glyph shell is selected by default.

   ```sh
   mkdir -p "$HOME/.local/state/rice"
   printf 'glyph\n' > "$HOME/.local/state/rice/shell"
   ```

6. Log out of the current session and select Hyprland at the display manager.

The shell starts automatically through `config/hypr/hyprland/execs.lua`. On first start it creates `~/.config/demonshot/kitty.conf`, `~/.config/demonshot/hypridle.conf`, and `~/.config/demonshot/rules.json`. It also links the terminal configuration files from `config/quickshell/glyph/term` into `~/.config`.

## Color schemes

Open the settings menu with `Super` and `I`. The `scheme` selector is located in the `LOOK` section. Two schemes are available:

| Scheme | Background | Foreground |
|---|---|---|
| `everblush` | `#141b1e` | `#dadada` |
| `aphelion` | `#101319` | `#f4f3ee` |

The selected scheme is stored as the `scheme` value in `~/.local/state/rice/glyph.json`. The default value is `everblush`.

Changing the scheme applies the new palette to the following elements:

- Hyprland active and inactive borders, shadow, group bar, and background color.
- Glyph shell surfaces, text, accents, and indicators.
- The kitty terminal foreground, background, cursor, and the sixteen ANSI colors.

The kitty palette is written to `~/.config/demonshot/kitty.conf`. Font, padding, tab appearance, cursor animation, selection colors, URL colors, and key maps remain in `~/.config/kitty/kitty.conf`.

The last line of `~/.config/kitty/kitty.conf` must remain:

```
include ~/.config/demonshot/kitty.conf
```

Without this include, kitty does not load the generated palette.

## Configuration notes

- Default applications and workspace key bindings are defined in `config/hypr/variables.lua`.
- Window manager key bindings are defined in `config/hypr/hyprland/keybinds.lua`.
- Local overrides are stored in `config/hypr/user.lua`. This file contains the monitor layout and the bspwm key bindings used on this system. Adjust monitor names and positions when the hardware differs.
- The color tables used by Hyprland are stored in `config/hypr/scheme`.
- The Glyph scheme definitions and the kitty palette generator are stored in `config/quickshell/glyph/Theme.qml`.
- The `scheme` selector is defined in `config/quickshell/glyph/prefs/Prefs.qml`.
- The shell applies the theme after a scheme change through the `onSchemeChanged` handler in `config/quickshell/glyph/shell.qml`.

## Verification

Check the Hyprland configuration for errors after login.

```sh
hyprctl configerrors
```

List the running Quickshell instances.

```sh
qs list --all
```

Confirm that kitty resolves the generated palette. The command prints the effective background and foreground values.

```sh
kitty +runpy 'from kitty.config import load_config; c = load_config("'"$HOME"'/.config/kitty/kitty.conf"); print(c.background, c.foreground)'
```

After selecting `aphelion`, the values are `#101319` and `#f4f3ee`. After selecting `everblush`, the values are `#141b1e` and `#dadada`.

## License

The configuration files in this directory are distributed under the GNU General Public License version 3. The complete license text is available in `hyprland/LICENSE`. The font files remain under the SIL Open Font License. The license text for the fonts is available in `.local/share/fonts/glyph/OFL.txt`. The first implementation was on [https://github.com/Nebelung-cloud/glyph-rice](https://github.com/Nebelung-cloud/glyph-rice)
