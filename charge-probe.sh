#!/bin/sh
set -eu
BAT=/sys/class/power_supply/bd7181x_bat
AC=/sys/class/power_supply/bd7181x_ac/online
CHARGING="$BAT/charging"
test "$(cat "$AC")" = 1
test "$(cat "$CHARGING")" = 1
restore() {
  printf '1\n' > "$CHARGING" || echo 'RESTORE WRITE FAILED' >&2
}
trap restore EXIT
trap 'exit 1' INT TERM HUP
echo '--- before ---'
for name in capacity charging status current_now; do printf '%s=' "$name"; cat "$BAT/$name"; done
printf '0\n' > "$CHARGING"
sleep 8
echo '--- disabled ---'
for name in capacity charging status current_now; do printf '%s=' "$name"; cat "$BAT/$name"; done
test "$(cat "$CHARGING")" = 0
printf '1\n' > "$CHARGING"
sleep 8
echo '--- restored ---'
for name in capacity charging status current_now; do printf '%s=' "$name"; cat "$BAT/$name"; done
test "$(cat "$CHARGING")" = 1
trap - EXIT
echo 'RESTORED'
