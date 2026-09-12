#!/bin/bash

ewwconf="$HOME/.config/bspwm/eww"

# runtime scratch files must exist even after the cache dir is cleared
mkdir -p "$ewwconf/cache/multi_win" "$ewwconf/cache/multi_winames"
: > "$ewwconf/cache/win_ids"
: > "$ewwconf/cache/active_winid"
: > "$ewwconf/cache/refresh_dock"
[ -f "$ewwconf/cache/pinned_apps" ] || echo '[]' > "$ewwconf/cache/pinned_apps"
[ -f "$ewwconf/cache/icons" ] || : > "$ewwconf/cache/icons"

. "$ewwconf/cache/icons" # load icons cache

# Generates array of objects
# Each object has icon & id property
gen_taskbar() {

	# Get the list of window IDs
	win_ids=$(xprop -root _NET_CLIENT_LIST | cut -d'#' -f2)
	echo $win_ids >$ewwconf/cache/win_ids &
	echo $(xprop -root _NET_ACTIVE_WINDOW | cut -d'#' -f2) >$ewwconf/cache/active_winid &

	str=''                                 # used for checking duplicate wm_classes
	json=$(cat $ewwconf/cache/pinned_apps) # final str, used by eww!
	json=${json%?}                         # rm last ]

	comma=,
	index=0

	for id in $win_ids; do

		if [ "$json" = "[" ] && [ $index -eq 0 ]; then
			comma=""
		else
			comma=,
		fi

		wm_class=$(xprop -id "$id" WM_CLASS)

		if [ "${str#*$wm_class}" = "$str" ]; then
			str="$str $wm_class"

			# used for getting values of icon path vars
			wm_class2=$(echo $wm_class | cut -d'"' -f4 | xargs "$(dirname "$0")/utils.sh" sanitize_var)
			gtk_app_id=$(xprop -id "$id" | grep GTK_APPLICATION_ID | cut -d'"' -f2 | xargs "$(dirname "$0")/utils.sh" sanitize_var)

			# store window state & use it for taskicon click action
			win_state=$("$(dirname "$0")/utils.sh" get_win_state $id)

			# break from loop as soon as we get the icon
			for class in "$wm_class2" "$gtk_app_id"; do
				icon=$(eval echo \$$class)

				if [ -n "$icon" ]; then
					break
				fi
			done

			# create stringified json object
			if [ -n "$icon" ] && [ "$icon" != "$" ]; then

				if [ -z "${json##*\"$wm_class2\"*}" ]; then
					json=$("$(dirname "$0")/utils.sh" add_jsonprops "$json" $wm_class2 $id $win_state)
				else
					json_obj='{
          "name": "'"$wm_class2"'",
          "icon": "'"$icon"'",
          "id": "'"$id"'",
          "state": "'"$win_state"'"
          }'
					json="$json $comma $json_obj"
				fi

				index=$((index + 1))
			fi
		fi
	done

	json="$json  ]"

	eww -c $ewwconf update apps="$json"
}

update_taskbar() {
	gen_taskbar
	"$(dirname "$0")/utils.sh" cache_multi_wins
}

# mtimes of the .desktop dirs - changes when an app is installed/removed
appdirs_state() {
	stat -c '%Y' /usr/share/applications /usr/local/share/applications "$HOME/.local/share/applications" 2>/dev/null
}

# update dock
while true; do

	# new/removed .desktop files -> rebuild icon cache, then the taskbar
	appsstate="$(appdirs_state)"
	if [ "${appsoldstate}" != "${appsstate}" ]; then
		"$(dirname "$0")/gen_icons.sh"
		. "$ewwconf/cache/icons"
		update_taskbar
	fi
	appsoldstate="${appsstate}"

	# use xprop to test for changes in window events
	# update the taskbar only when window state changes occur
	winstate="$(xprop -root)"
	test "${oldstate}" = "${winstate}" || update_taskbar
	oldstate="${winstate}"

	# to refresh the dock, any part of the scripts could just echo new char to this file
	refresh_file_val="$(cat $ewwconf/cache/refresh_dock)"
	test "${refresh_file_oldval}" = "${refresh_file_val}" || update_taskbar
	refresh_file_oldval="${refresh_file_val}"
	sleep 0.5
done