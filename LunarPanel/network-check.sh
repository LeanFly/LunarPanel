#!/bin/sh
OUT=/mnt/us/extensions/LunarPanel/network.txt
{
  echo 'Lunar Panel network diagnostics'
  date
  echo '--- wireless status ---'
  /usr/bin/lipc-get-prop com.lab126.cmd wirelessEnable 2>&1 || :
  echo '--- DNS configuration ---'
  cat /etc/resolv.conf 2>&1 || :
  echo '--- weather endpoint ---'
  /usr/bin/curl -fsS --connect-timeout 8 --max-time 15 -o /dev/null -w 'HTTP %{http_code}\n' 'https://api.open-meteo.com/v1/forecast?latitude=31.2304&longitude=121.4737&current=temperature_2m' 2>&1 || :
  echo '--- air quality endpoint ---'
  /usr/bin/curl -fsS --connect-timeout 8 --max-time 15 -o /dev/null -w 'HTTP %{http_code}\n' 'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=31.2304&longitude=121.4737&current=european_aqi' 2>&1 || :
  echo '--- complete ---'
} > "$OUT" 2>&1
