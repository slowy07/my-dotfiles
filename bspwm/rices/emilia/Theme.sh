#!/usr/bin/env bash
set_bspwm_config() {
		bspc config border_width 0
		bspc config top_padding 50
		bspc config bottom_padding 1
		bspc config normal_border_color "#414868"
		bspc config active_border_color "#c0caf5"
		bspc config focused_border_color "#bb9af7"
		bspc config presel_feedback_color "#7aa2f7"
		bspc config left_padding 2
		bspc config right_padding 2
		bspc config window_gap 6
}

# Reload terminal colors
set_term_config() {
		sed -i "$HOME"/.config/alacritty/fonts.yml \
		-e "s/family: .*/family: JetBrainsMono Nerd Font/g" \
		-e "s/size: .*/size: 10/g"
		
		cat > "$HOME"/.config/alacritty/colors.yml <<- _EOF_
				# Colors (Tokyo Night) Emilia Rice
				colors:
				  primary:
				    background: '#101419'
				    foreground: '#cbced3'

				  normal:
				    black:   '#101419'
				    red:     '#dd6777'
				    green:   '#90ceaa'
				    yellow:  '#ceac67'
				    blue:    '#86aaec'
				    magenta: '#c296eb'
				    cyan:    '#93cee9'
				    white:   '#cbced3'

				  bright:
				    black:   '#1f2328'
				    red:     '#f7768e'
				    green:   '#9ece6a'
				    yellow:  '#e0af68'
				    blue:    '#7aa2f7'
				    magenta: '#bb9af7'
				    cyan:    '#7dcfff'
				    white:   '#c0caf5'

				  cursor:
				    cursor: '#bb9af7'
				    text:	'#1a1b26'
_EOF_
}

# Set compositor configuration
set_picom_config() {
		sed -i "$HOME"/.config/bspwm/picom.conf \
			-e "s/normal = .*/normal =  { fade = false; shadow = false; }/g" \
			-e "s/shadow-color = .*/shadow-color = \"#000000\"/g" \
			-e "s/corner-radius = .*/corner-radius = 15/g" \
			-e "s/\".*:class_g = 'Alacritty'\"/\"100:class_g = 'Alacritty'\"/g" \
			-e "s/\".*:class_g = 'FloaTerm'\"/\"100:class_g = 'FloaTerm'\"/g"
}

# Set dunst notification daemon config
set_dunst_config() {
		sed -i "$HOME"/.config/bspwm/dunstrc \
		-e "s/transparency = .*/transparency = 0/g" \
		-e "s/frame_color = .*/frame_color = \"#1a1b26\"/g" \
		-e "s/separator_color = .*/separator_color = \"#c0caf5\"/g" \
		-e "s/font = .*/font = JetBrainsMono Nerd Font Medium 9/g" \
		-e "s/foreground='.*'/foreground='#f9f9f9'/g"
		
		sed -i '/urgency_low/Q' "$HOME"/.config/bspwm/dunstrc
		cat >> "$HOME"/.config/bspwm/dunstrc <<- _EOF_
				[urgency_low]
				timeout = 3
				background = "#1a1b26"
				foreground = "#c0caf5"

				[urgency_normal]
				timeout = 6
				background = "#1a1b26"
				foreground = "#c0caf5"

				[urgency_critical]
				timeout = 0
				background = "#1a1b26"
				foreground = "#c0caf5"
_EOF_
}

# Launch the bar
launch_bars() {
		polybar -q emi-bar -c ${rice_dir}/config.ini &
}


### ---------- Apply Configurations ---------- ###

set_bspwm_config
set_term_config
set_picom_config
set_dunst_config
launch_bars
ln -sf ~/.config/bspwm/rices/emilia/settings.ini ~/.config/gtk-3.0/settings.ini
nwg-look -a
