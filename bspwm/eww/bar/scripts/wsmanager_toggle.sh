#!/usr/bin/env bash
# eww 0.6.0 `open --toggle` never closes; list-windows lists config windows,
# so gate toggle state on active-windows.
EWW_C=("eww" "-c" "$HOME/.config/bspwm/eww")
WIN=wsmanager-popup
if "${EWW_C[@]}" active-windows 2>/dev/null | grep -q "$WIN"; then
    "${EWW_C[@]}" close "$WIN"
else
    "${EWW_C[@]}" open "$WIN"
fi