#!/usr/bin/env bash


# Set bspwm configuration for Aline
set_bspwm_config() {
		bspc config border_width 0
		bspc config top_padding 8
		bspc config bottom_padding 65
		bspc config normal_border_color "#ca9ee6"
		bspc config active_border_color "#ca9ee6"
		bspc config focused_border_color "#8CAAEE"
		bspc config presel_feedback_color "#E78284"
		bspc config left_padding 6
		bspc config right_padding 6
		bspc config window_gap 6
}

# Reload terminal colors
set_term_config() {
		sed -i "$HOME"/.config/alacritty/fonts.yml \
		-e "s/family: .*/family: JetBrainsMono Nerd Font/g" \
		-e "s/size: .*/size: 10/g"
		
		cat > "$HOME"/.config/alacritty/colors.yml <<- _EOF_
				# Colors (Pencil light) Aline rice
          colors:
            primary:
              background: '0x141b1e'
              foreground: '0xdadada'

            cursor:
              text: '0xdadada'
              cursor: '0xdadada'
            normal:
              black:   '0x232a2d'
              red:     '0xe57474'
              green:   '0x8ccf7e'
              yellow:  '0xe5c76b'
              blue:    '0x67b0e8'
              magenta: '0xc47fd5'
              cyan:    '0x6cbfbf'
              white:   '0xb3b9b8'
            bright:
              black:   '0x2d3437'
              red:     '0xef7e7e'
              green:   '0x96d988'
              yellow:  '0xf4d67a'
              blue:    '0x71baf2'
              magenta: '0xce89df'
              cyan:    '0x67cbe7'
              white:   '0xbdc3c2'
_EOF_
}

# Set compositor configuration
set_picom_config() {
		sed -i "$HOME"/.config/bspwm/picom.conf \
			-e "s/normal = .*/normal =  { fade = false; shadow = false; }/g" \
			-e "s/shadow-color = .*/shadow-color = \"#000000\"/g" \
			-e "s/corner-radius = .*/corner-radius = 6/g" \
			-e "s/\".*:class_g = 'Alacritty'\"/\"95:class_g = 'Alacritty'\"/g" \
			-e "s/\".*:class_g = 'FloaTerm'\"/\"95:class_g = 'FloaTerm'\"/g"
}

# Set dunst notification daemon config
set_dunst_config() {
		sed -i "$HOME"/.config/bspwm/dunstrc \
		-e "s/transparency = .*/transparency = 3/g" \
		-e "s/frame_color = .*/frame_color = \"#141b1e\"/g" \
		-e "s/separator_color = .*/separator_color = \"#fb007a\"/g" \
		-e "s/font = .*/font = JetBrainsMono Nerd Font Medium 9/g" \
		-e "s/foreground='.*'/foreground='#20bbfc'/g"
		
		sed -i '/urgency_low/Q' "$HOME"/.config/bspwm/dunstrc
		cat >> "$HOME"/.config/bspwm/dunstrc <<- _EOF_
				[urgency_low]
				timeout = 3
				background = "#e5eafe"
				foreground = "#51576d"

				[urgency_normal]
				timeout = 6
				background = "#e5eafe"
				foreground = "#51576d"

				[urgency_critical]
				timeout = 0
				background = "#e5eafe"
				foreground = "#51576d"
_EOF_
}

# Launch the bar
launch_bars() {
		polybar -q aline-bar -c ${rice_dir}/config.ini &
}


### ---------- Apply Configurations ---------- ###

set_bspwm_config
set_term_config
set_dunst_config
launch_bars
