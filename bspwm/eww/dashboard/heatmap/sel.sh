#!/bin/sh
val="$1"
if [ -f /tmp/hm_sel ] && [ "$(cat /tmp/hm_sel)" = "$val" ]; then
    : > /tmp/hm_sel
else
    printf '%s' "$val" > /tmp/hm_sel
fi