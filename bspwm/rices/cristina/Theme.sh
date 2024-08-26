#!/usr/bin/env bash
set_bspwm_config() {
		bspc config border_width 0
		bspc config top_padding 70
		bspc config bottom_padding 20
		bspc config normal_border_color "#9bced7"
		bspc config active_border_color "#9bced7"
		bspc config focused_border_color "#c3a5e6"
		bspc config presel_feedback_color "#c3a5e6"
		bspc config left_padding 10
		bspc config right_padding 10
		bspc config window_gap 8
}

# Reload terminal colors
set_term_config() {
		sed -i "$HOME"/.config/alacritty/fonts.yml \
		-e "s/family: .*/family: JetBrainsMono Nerd Font/g" \
		-e "s/size: .*/size: 10/g"
		
		cat > "$HOME"/.config/kitty/current-theme.conf <<- _EOF_
foreground              #dadada
background              #141b1e
selection_foreground    #dadada
selection_background    #2d3437

# Cursor colors
cursor                  #2d3437
cursor_text_color       #dadada

# Normal colors
color0                  #232a2d
color1                  #e57474
color2                  #8ccf7e
color3                  #e5c76b
color4                  #67b0e8
color5                  #c47fd5
color6                  #6cbfbf
color7                  #b3b9b8

# Bright colors
color8                  #2d3437
color9                  #ef7e7e
color10                 #96d988
color11                 #f4d67a
color12                 #71baf2
color13                 #ce89df
color14                 #67cbe7
color15                 #bdc3c2

# Tab colors 
active_tab_foreground   #141b1e
active_tab_background   #8ccf7e
inactive_tab_foreground #dadada
inactive_tab_background #141b1e
_EOF_
}

# Set compositor configuration
set_picom_config() {
		sed -i "$HOME"/.config/bspwm/picom.conf \
			-e "s/normal = .*/normal =  { fade = false; shadow = false; }/g" \
			-e "s/shadow-color = .*/shadow-color = \"#000000\"/g" \
			-e "s/corner-radius = .*/corner-radius = 6/g" \
			-e "s/\".*:class_g = 'Alacritty'\"/\"100:class_g = 'Alacritty'\"/g" \
			-e "s/\".*:class_g = 'FloaTerm'\"/\"100:class_g = 'FloaTerm'\"/g"
}

# Set dunst notification daemon config
set_dunst_config() {
		sed -i "$HOME"/.config/bspwm/dunstrc \
		-e "s/transparency = .*/transparency = 0/g" \
		-e "s/frame_color = .*/frame_color = \"#1f1d29\"/g" \
		-e "s/separator_color = .*/separator_color = \"#ea6f91\"/g" \
		-e "s/font = .*/font = JetBrainsMono Nerd Font Medium 9/g" \
		-e "s/foreground='.*'/foreground='#9bced7'/g"
		
		sed -i '/urgency_low/Q' "$HOME"/.config/bspwm/dunstrc
		cat >> "$HOME"/.config/bspwm/dunstrc <<- _EOF_
				[urgency_low]
				timeout = 3
				background = "#1f1d29"
				foreground = "#eaeaea"

				[urgency_normal]
				timeout = 6
				background = "#1f1d29"
				foreground = "#eaeaea"

				[urgency_critical]
				timeout = 0
				background = "#1f1d29"
				foreground = "#eaeaea"
_EOF_
}

# Launch the bar and or eww widgets
launch_bars() {
		eww -c ${rice_dir}/widgets daemon &
		polybar -q cristina-bar -c ${rice_dir}/config.ini &
}


### ---------- Apply Configurations ---------- ###

set_bspwm_config
set_term_config
set_picom_config
set_dunst_config
launch_bars
