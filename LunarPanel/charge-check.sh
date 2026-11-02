#!/bin/sh
OUT=/mnt/us/extensions/LunarPanel/charge-check.txt
{
  echo 'Lunar Panel charge-control diagnostics (read-only)'
  date
  for supply in /sys/class/power_supply/*; do
    [ -d "$supply" ] || continue
    echo "--- $supply attributes ---"
    ls -l "$supply/" 2>&1
    for name in charge_control_limit charge_control_limit_max charge_control_start_threshold charge_control_end_threshold charge_behaviour charging_enabled charge_enabled input_suspend constant_charge_current_max constant_charge_voltage_max status capacity online; do
      f="$supply/$name"
      if [ -r "$f" ]; then printf '%s: ' "$f"; cat "$f" 2>&1; fi
    done
  done
  echo '--- complete ---'
} > "$OUT" 2>&1
