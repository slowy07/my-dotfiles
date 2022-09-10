#!/bin/dash

flameshot gui --raw > ~/Pictures/image.png

# rounded corners
convert ~/Pictures/image.png \
     \( +clone  -alpha extract \
        -draw 'fill black polygon 0,0 0,5 5,0 fill white circle 5,5 5,0' \
        \( +clone -flip \) -compose Multiply -composite \
        \( +clone -flop \) -compose Multiply -composite \
     \) -alpha off -compose CopyOpacity -composite ~/Pictures/image.png

# shadow
convert ~/Pictures/image.png \( +clone -background black -shadow 40x5+0+0 \) \
+swap -background none -layers merge +repage ~/Pictures/image.png; \

# white backdrop
convert ~/Pictures/image.png -bordercolor white -border 10 ~/Pictures/image.png

# copy to clipboard
xclip -selection clipboard -i ~/Pictures/image.png -t image/png
