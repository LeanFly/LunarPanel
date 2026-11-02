#!/bin/sh
BASE=/mnt/us/extensions/LunarPanel
PIDFILE="$BASE/panel.pid"
LOG="$BASE/panel.log"
FBINK=/mnt/us/libkh/bin/fbink
POWER_OWNED=0

release_power() {
  if [ "$POWER_OWNED" = 1 ]; then
    /usr/bin/lipc-set-prop com.lab126.powerd preventScreenSaver 0 || return 1
    POWER_OWNED=0
    echo "$(date): screen saver prevention released"
  fi
}

check_power() {
  if [ "$POWER_OWNED" = 0 ]; then
    current=$(/usr/bin/lipc-get-prop com.lab126.powerd preventScreenSaver 2>/dev/null)
    if [ "$current" = 0 ] && /usr/bin/lipc-set-prop com.lab126.powerd preventScreenSaver 1; then
      POWER_OWNED=1
      echo "$(date): screen saver prevention enabled while panel is running"
    fi
  fi
}

render_panel() {
  if /usr/bin/lua "$BASE/panel.lua"; then
    if "$FBINK" -q -f -g "file=$BASE/panel.pgm"; then
      echo "$(date): panel refreshed"
    else
      echo "$(date): panel display failed"
    fi
  else
    echo "$(date): panel generation failed"
  fi
}

fetch_source() {
  source_id="$1"
  endpoint="$2"
  cache="$BASE/hot-$source_id.json"
  if /usr/bin/curl -fsS --max-time 15 "$endpoint" > "$cache.tmp" && /usr/bin/lua "$BASE/news-check.lua" "$cache.tmp"; then
    mv "$cache.tmp" "$cache" || return 1
    date +%s > "$cache.time"
    rm -f "$BASE/hot-$source_id.stale"
    echo "$(date): hot news fetched: $source_id"
  else
    rm -f "$cache.tmp"
    echo stale > "$BASE/hot-$source_id.stale"
    echo "$(date): hot news source failed: $source_id; retaining cached data"
  fi
}

fetch_news() {
  fetch_source weibo 'https://v2.xxapi.cn/api/weibohot'
  fetch_source douyin 'https://v2.xxapi.cn/api/douyinhot'
  fetch_source zhihu 'https://60s.viki.moe/v2/zhihu'
  fetch_source ithome 'https://60s.viki.moe/v2/it-news'
}

case "$1" in
  start)
    if [ -f "$PIDFILE" ]; then
      pid=$(cat "$PIDFILE")
      case "$pid" in ''|*[!0-9]*) ;; *) if [ -r "/proc/$pid/cmdline" ] && tr '\000' ' ' < "/proc/$pid/cmdline" | grep -q 'LunarPanel/panel.sh loop'; then exit 0; fi ;; esac
    fi
    sh "$BASE/panel.sh" loop </dev/null >>"$LOG" 2>&1 &
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      pid=$(cat "$PIDFILE")
      case "$pid" in ''|*[!0-9]*) ;; *) if [ -r "/proc/$pid/cmdline" ] && tr '\000' ' ' < "/proc/$pid/cmdline" | grep -q 'LunarPanel/panel.sh loop'; then kill "$pid" 2>/dev/null || :; fi ;; esac
      rm -f "$PIDFILE"
    fi
    ;;
  loop)
    echo $$ > "$PIDFILE"
    trap 'release_power; rm -f "$PIDFILE"; exit' TERM INT
    sleep 3
    while :; do
      check_power
      weather_url='https://api.open-meteo.com/v1/forecast?latitude=31.2304&longitude=121.4737&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Asia%2FShanghai'
      air_url='https://air-quality-api.open-meteo.com/v1/air-quality?latitude=31.2304&longitude=121.4737&current=european_aqi&timezone=Asia%2FShanghai'
      if /usr/bin/curl -fsS --max-time 20 "$weather_url" > "$BASE/weather-api.tmp"; then
        /usr/bin/curl -fsS --max-time 20 "$air_url" > "$BASE/air-api.tmp" || rm -f "$BASE/air-api.tmp"
        if /usr/bin/lua "$BASE/weather-fetch.lua" "$BASE/weather-api.tmp" "$BASE/air-api.tmp"; then
          rm -f "$BASE/weather.stale"
        else
          echo stale > "$BASE/weather.stale"
          echo "$(date): weather parse failed; retaining cached data"
        fi
      else
        echo stale > "$BASE/weather.stale"
        echo "$(date): weather request failed; retaining cached data"
      fi
      rm -f "$BASE/weather-api.tmp" "$BASE/air-api.tmp"
      fetch_news
      render_panel
      remaining=30
      while [ "$remaining" -gt 0 ]; do
        sleep 60 &
        wait $!
        check_power
        remaining=$((remaining - 1))
        if [ "$remaining" -gt 0 ] && [ $((remaining % 5)) -eq 0 ]; then render_panel; fi
      done
    done
    ;;
esac
