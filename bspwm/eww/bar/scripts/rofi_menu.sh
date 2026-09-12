#!/bin/bash

ewwconf="$HOME/.config/bspwm/eww"

win_ids=$1
win_names=$2

mouse_x=$3

# gap between the menu's bottom edge and the dock
gap=6

# menu width must match `width` in rofi/menu.rasi
menu_width=300

# anchor to the live dock geometry instead of the mouse cursor, so the menu
# always sits a fixed gap above the dock regardless of where the icon is clicked
dock_id=$(xdotool search --name "Eww - dock" | head -1)
dock_top=$(xdotool getwindowgeometry "$dock_id" 2>/dev/null | awk '/Position/ {split($2, a, ","); print a[2]}')
[ -z "$dock_top" ] && dock_top=$(xdotool getdisplaygeometry | cut -d' ' -f2)

screen_width=$(xdotool getdisplaygeometry | cut -d' ' -f1)
screen_height=$(xdotool getdisplaygeometry | cut -d' ' -f2)

# menu/rofi is anchored bottom-left (see menu.rasi `location: 7`), so yoffset
# is measured from the screen's bottom edge, not the window's own (guessed)
# height -- this keeps the gap exact no matter how tall rofi actually renders
yaxis=$(( (dock_top - gap) - screen_height ))
xaxis=$(( mouse_x - (menu_width / 2) ))

# clamp horizontally so the menu never spills off screen
[ "$xaxis" -lt 0 ] && xaxis=0
max_x=$(( screen_width - menu_width ))
[ "$xaxis" -gt "$max_x" ] && xaxis=$max_x


# # Use Rofi to display the list of win IDs and select one
selected_index=$(echo "$win_names" | rofi -config "$ewwconf/bar/rofi/menu.rasi" -dmenu -i -p "Search " -xoffset $xaxis -yoffset $yaxis -format i -hover-select -no-fixed-num-lines )
selected_index=$(($selected_index + 1))

selected_win=$(echo "$win_ids" | cut -d ' ' -f $selected_index)

echo $selected_win | tr -d ","

get_win_state() {
	win_state="unfocused"
	net_wm_state=$(xprop -id "$1" _NET_WM_STATE | cut -d'=' -f2)
	active_win=$(cat $ewwconf/cache/active_winid)

	if [ "$net_wm_state" = " _NET_WM_STATE_HIDDEN" ]; then
		win_state="minimized"
	elif [ "$1" = "$active_win" ]; then
		win_state="focused"
	fi

	echo $win_state
}

win_state=$(get_win_state $selected_win)

"$(dirname "$0")/utils.sh" toggle_win $selected_win $win_state