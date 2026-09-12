#!/bin/bash
# netspeed.sh - eww poll: current average down/up speed since last sample
f=/tmp/netspeed_prev
read -r pnow prx ptx < "$f" 2>/dev/null
now=$(date +%s)
read -r crx ctx <<< "$(awk 'NR>2 && $1 != "lo:" {r+=$2; t+=$10} END {print r, t}' /proc/net/dev)"
if [ -n "$pnow" ] && [ -n "$prx" ] && [ "$((now-pnow))" -gt 0 ]; then
  dt=$((now-pnow)); down=$(( (crx-prx) / dt )); up=$(( (ctx-ptx) / dt ))
  h() { [ "$1" -ge 1048576 ] && echo "$(( $1 / 1048576 ))M" || { [ "$1" -ge 1024 ] && echo "$(( $1 / 1024 ))K" || echo "$1"B; }; }
  printf '↓ %s  ↑ %s\n' "$(h "$down")" "$(h "$up")"
else
  printf '↓ 0B  ↑ 0B\n'
fi
printf '%s %s %s\n' "$now" "$crx" "$ctx" > "$f"