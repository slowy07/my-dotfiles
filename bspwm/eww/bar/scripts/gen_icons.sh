#!/bin/bash

ewwconf="$HOME/.config/bspwm/eww"
mkdir -p "$ewwconf/cache"

. "$(dirname "$0")/utils.sh"

echo -n > $ewwconf/cache/icons

grep_val() {
	matched_str=$(grep "$1" -m 1 "$2")
	echo "${matched_str#*=}"
}

generate_iconpaths() {
	if [ -d "$1" ]; then
		for desktop_file in "$1"/*.desktop; do
			is_termapp=$(grep_val "^Terminal=" "$desktop_file")
			no_display=$(grep_val "^NoDisplay=" "$desktop_file")

			if [ "$is_termapp" != "true" ] && [ "$no_display" != "true" ]; then

				# Read values of icon and Name variables
				icon=$(grep_val "^Icon=" "$desktop_file")
				name=$(grep_val "^Name=" "$desktop_file" | tr ' -.' '_' | tr '[:upper:]' '[:lower:]')

				iconpath=$(find_icon "$icon")

				echo "$name=$iconpath " >> $ewwconf/cache/icons

				name2=$(basename "$desktop_file" .desktop | tr ' -.' '_' | tr '[:upper:]' '[:lower:]')

				if [ "$name" != "$name2" ]; then
					echo "$name2=$iconpath" >> $ewwconf/cache/icons
				fi
			fi
		done
	fi
}

generate_iconpaths "/usr/share/applications"
generate_iconpaths "/usr/local/share/applications"
generate_iconpaths "$HOME/.local/share/applications"