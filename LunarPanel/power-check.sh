#!/bin/sh
OUT=/mnt/us/extensions/LunarPanel/power.txt
{
  echo 'Lunar Panel power diagnostics'
  date
  echo '--- powerd properties ---'
  for prop in state status isCharging battLevel battStateInfo preventScreenSaver; do
    printf '%s: ' "$prop"
    /usr/bin/lipc-get-prop com.lab126.powerd "$prop" 2>&1 || :
  done
  echo '--- power tools ---'
  for tool in lipc-get-prop lipc-set-prop rtcwake; do command -v "$tool" 2>/dev/null || :; done
  echo '--- RTC and wakeup files ---'
  ls -l /sys/class/rtc/rtc0/wakealarm /sys/power/wake_lock /sys/power/wake_unlock /sys/class/power_supply 2>&1 || :
  echo '--- power supplies ---'
  for f in /sys/class/power_supply/*/type /sys/class/power_supply/*/online /sys/class/power_supply/*/status; do
    if [ -r "$f" ]; then printf '%s: ' "$f"; cat "$f"; fi
  done
  echo '--- complete ---'
} > "$OUT" 2>&1
