#!/bin/bash

ewwconf="$HOME/.config/bspwm/eww"

# shell vars dont support special chars other than _, so remove them!
sanitize_var() {
	echo $1 | tr ' -.' '_' | tr '[:upper:]' '[:lower:]'
}

get_mousecoords() {
	eval $(xdotool getmouselocation --shell)
	mouse_x=$X
	mouse_y=$Y
}

# takes id as arg and counts window ids by same wm_class
count_wins_byid() {
	wm_class=$(xprop -id $1 WM_CLASS | cut -d'=' -f2)

	counter=0

	for id in $2; do
		tmp_wm_class=$(xprop -id $id WM_CLASS | cut -d'=' -f2)

		if [ "$wm_class" = "$tmp_wm_class" ]; then
			counter=$((counter + 1))
		fi
	done

	echo $counter
}

get_win_state() {
	win_state="unfocused"
	net_wm_state=$(xprop -id "$1" _NET_WM_STATE | cut -d'=' -f2)
	active_win=$(cat $ewwconf/cache/active_winid)

	if [ $(count_wins_byid $1 "$3") = 1 ]; then
		if [ "$net_wm_state" = " _NET_WM_STATE_HIDDEN" ]; then
			win_state="minimized"
		elif [ "$1" = "$active_win" ]; then
			win_state="focused"
		fi

		echo $win_state
	else
		active_winclass=$(xprop -id "$active_win" WM_CLASS)
		tmp_winclass=$(xprop -id "$1" WM_CLASS)

		if [ "$tmp_winclass" = "$active_winclass" ]; then
			echo "focused"
		else
			tmp_winclass=$(echo $tmp_winclass | cut -d'"' -f4)

			visible_wincount=$(xdotool search --onlyvisible --classname $tmp_winclass | wc -l)
			echo $([ "$visible_wincount" = 0 ] && echo minimized || echo unfocused)
		fi
	fi
}

# returns ids of multiple windows of same wm_class (arg)
get_multiple_wins() {
	win_ids=$2
	multi_wins=""

	for id in $win_ids; do
		wm_class=$(xprop -id $id WM_CLASS | cut -d'"' -f4)
		wm_class=$(sanitize_var "$wm_class")

		if [ "$wm_class" = "$1" ]; then
			multi_wins="$multi_wins $id"
			classes="$classes $wm_class"
		fi
	done

	echo $multi_wins >$ewwconf/cache/multi_win/$1

	# cache names too
	win_names=""

	for id in $multi_wins; do
		name=$(xprop -id $id WM_NAME | cut -d'"' -f2)
		win_names="$win_names$name"

		# Check if the current iteration is not the last one
		if [ "$id" != "${multi_wins##* }" ]; then
			win_names="$win_names\n"
		fi
	done

	echo $win_names >$ewwconf/cache/multi_winames/$1
}

# generates cache files of apps who have multi wins opened
cache_multi_wins() {
	rm -rf $ewwconf/cache/multi_win/*
	rm -rf $ewwconf/cache/multi_winames/*

	win_ids=$(cat $ewwconf/cache/win_ids)

	for id in $win_ids; do
		id_wincount=$(count_wins_byid $id "$win_ids")

		wm_class=$(xprop -id $id WM_CLASS | cut -d'"' -f4)
		wm_class=$(sanitize_var "$wm_class")

		filename="$ewwconf/cache/multi_win/$wm_class"

		if [ $id_wincount -gt 1 ] && [ ! -e "$filename" ]; then
			get_multiple_wins $wm_class "$win_ids"
		fi
	done
}

toggle_win() {
	if [ "$2" = "minimized" ] || [ "$2" = "unfocused" ]; then
		xdotool windowactivate $1
	else
		xdotool windowminimize $1
	fi
}

taskicon_click() {
	# run cmd of pinned app ($2 is null cuz there's no id prop for pinned app json object)
	if [ $2 = "null" ]; then
		$4 &
		exit
	fi

	win_ids=$(cat $ewwconf/cache/win_ids)

	if [ $(count_wins_byid $2 "$win_ids") = 1 ]; then
		toggle_win "$2" "$3"
	else
		multi_wins=$(cat $ewwconf/cache/multi_win/$1)
		multi_winames=$(cat $ewwconf/cache/multi_winames/$1)

		get_mousecoords
		"$(dirname "$0")/rofi_menu.sh" "$multi_wins" "$multi_winames" "$mouse_x" "$mouse_y"
	fi
}

# right click action
menu_click() {
	toggle_win $1 $2
}

pin_app_toggle() {
	clicked_win=$(eww -c $ewwconf get clicked_win)

	if [ "$clicked_win" = "$1_on" ]; then
		eww -c $ewwconf update clicked_win="$1_off"
	else
		eww -c $ewwconf update clicked_win="$1_on"
	fi
}

pin_app() {
	file=$ewwconf/cache/pinned_apps
	firstchar=""
	comma=""
	pinned_apps=""

	if [ "$(cat "$file")" != "[]" ]; then
		comma=","
		pinned_apps=$(cat "$file")
		pinned_apps=${pinned_apps%?}
	else
		firstchar="["
	fi

	pid=$(xprop -id "$3" | grep -i pid | cut -d'=' -f2 | tr -d ' ')
	cmd=$(readlink -f "/proc/$pid/exe" | sed 's/ (deleted)$//')

	json='{
	 "name": "'"$1"'",
	 "icon": "'"$2"'",
	 "cmd": "'$cmd'"
   }'

	json="$comma $json"

	echo "$pinned_apps $firstchar $json ]" >"$file"
	eww -c $ewwconf update clicked_win=""
}

unpin_app() {
	file=$ewwconf/cache/pinned_apps

	result=$(awk -v target="$1" '
		BEGIN { RS="{"; first=1; printf "[" }
		NR==1 { next }
		{
			end = index($0, "}")
			body = substr($0, 1, end - 1)

			name = body
			sub(/.*"name"[ \t]*:[ \t]*"/, "", name)
			sub(/".*/, "", name)

			if (name != target) {
				if (!first) printf ","
				printf "{%s}", body
				first = 0
			}
		}
		END { printf "]" }
	' "$file")

	echo -n "$result" >"$file"
	echo -n x >>"$ewwconf/cache/refresh_dock"
	eww -c $ewwconf update clicked_win=""
}

add_jsonprops() {
	json="$1" \
		name="\"$2\"" \
		props="\"$2\", \"id\" : \"$3\", \"state\": \"$4\""
	echo "${json%%"$name"*}$props${json#*"$name"}"
}

# resolves a .desktop Icon= value to a real file: try Papirus, then the
# couple of places icons land when a theme doesn't have them (hicolor, pixmaps)
find_icon() {
	icon="$1"
	[ -z "$icon" ] && return 1

	case "$icon" in
	/*)
		[ -f "$icon" ] && echo "$icon"
		return
		;;
	esac

	for theme in Papirus-Dark Papirus hicolor; do
		for size in 48x48 scalable 64x64 32x32 24x24 16x16; do
			for ext in svg png xpm; do
				path="/usr/share/icons/$theme/$size/apps/$icon.$ext"
				[ -f "$path" ] && echo "$path" && return
			done
		done
	done

	for ext in svg png xpm; do
		path="/usr/share/pixmaps/$icon.$ext"
		[ -f "$path" ] && echo "$path" && return
	done

	return 1
}

toggle_volume() {
	val=$(eww -c $ewwconf get volume_slider)

	if [ "$val" = "true" ]; then
		new_val="false"
	else
		new_val="true"
	fi

	eww -c $ewwconf update volume_slider="$new_val"
}

toggle_netspeed() {
	val=$(eww -c $ewwconf get show_netspeed)

	if [ "$val" = "true" ]; then
		new_val="false"
	else
		new_val="true"
	fi

	eww -c $ewwconf update show_netspeed="$new_val"
}

"$@"