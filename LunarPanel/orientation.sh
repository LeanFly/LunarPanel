#!/bin/sh
BASE=/mnt/us/extensions/LunarPanel
case "$1" in left|right) ;; *) exit 1 ;; esac
printf '%s\n' "$1" > "$BASE/orientation.txt" || exit 1
(
  sleep 3
  output="/tmp/lunar-panel-orientation-$$.pgm"
  if /usr/bin/lua "$BASE/panel.lua" "$output"; then
    /mnt/us/libkh/bin/fbink -q -f -g "file=$output"
  fi
  rm -f "$output"
) </dev/null >>"$BASE/panel.log" 2>&1 &
