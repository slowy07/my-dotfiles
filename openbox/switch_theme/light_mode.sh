openbox_path="$HOME/.config/openbox"
polybar_path="$HOME/.config/openbox/gloom_light"
rofi_path="$HOME/.config/openbox/rofi"
terminal_path="$HOME/.config/alacritty"
xfce_term_path="$HOME/.config/xfce4/terminal"
geany_path="$HOME/.config/geany"
dunst_path="$HOME/.config/dunst"

set_wallpaper() {
  nitrogen --restore
}

change_polybar() {
  ${polybar_path}/launch.sh
}

change_terminal() {
	sed -i -e "s/family: .*/family: \"$1\"/g" 		${terminal_path}/fonts.yml
	sed -i -e "s/size: .*/size: $2/g" 				${terminal_path}/fonts.yml

	cat > ${terminal_path}/colors.yml <<- _EOF_
		## Colors configuration
		colors:
		  # Default colors
		  primary:
		    background: '0x323f4e'
		    foreground: '0xf8f8f2'
		  # Normal colors
		  normal:
		    black:   '0x3d4c5f'
		    red:     '0xf48fb1'
		    green:   '0xa1efd3'
		    yellow:  '0xf1fa8c'
		    blue:    '0x92b6f4'
		    magenta: '0xbd99ff'
		    cyan:    '0x87dfeb'
		    white:   '0xf8f8f2'
		  # Bright colors
		  bright:
		    black:   '0x56687e'
		    red:     '0xee4f84'
		    green:   '0x53e2ae'
		    yellow:  '0xf1ff52'
		    blue:    '0x6498ef'
		    magenta: '0x985eff'
		    cyan:    '0x24d1e7'
		    white:   '0xe5e5e5'
	_EOF_
}
