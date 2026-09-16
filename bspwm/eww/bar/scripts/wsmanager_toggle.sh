#!/bin/sh
# wsmanager_toggle.sh: deterministic toggle for the workspace-manager popup
# (eww 0.6.0 `open --toggle` never closes; list-windows lists config windows,
#  so gate on active-windows instead)
if eww -c "$HOME/.config/bspwm/eww" active-windows 2>/dev/null | grep -q "wsmanager-popup"; then
    eww -c "$HOME/.config/bspwm/eww" close wsmanager-popup
else
    eww -c "$HOME/.config/bspwm/eww" open wsmanager-popup
fi