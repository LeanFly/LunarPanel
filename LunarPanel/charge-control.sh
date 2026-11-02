#!/bin/sh

BASE=/mnt/us/extensions/LunarPanel
RUN=/tmp/lunarpanel-charge
BAT=/sys/class/power_supply/bd7181x_bat
AC=/sys/class/power_supply/bd7181x_ac/online
CHARGE="$BAT/charging"
LOG="$BASE/charge.log"

log() { echo "$(date): $*" >> "$LOG" 2>/dev/null || :; }

restore() {
  if printf '1\n' > "$CHARGE"; then
    log 'requested charging enabled'
    return 0
  fi
  log 'ERROR: could not restore charging'
  return 1
}

decide() {
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ "$1" -le 100 ] || return 1
  case "$2:$3" in 1:0|1:1|0:0|0:1) ;; *) return 1 ;; esac
  case "$4" in hold|charge) phase="$4" ;; *) return 1 ;; esac
  if [ "$1" -ge 80 ]; then phase=hold
  elif [ "$1" -le 40 ]; then phase=charge
  fi
  if [ "$2" = 0 ]; then action=restore
  elif [ "$phase" = hold ] && [ "$3" = 1 ]; then action=stop
  elif [ "$phase" = charge ] && [ "$3" = 0 ]; then action=start
  else action=hold
  fi
  echo "$action $phase"
}

cleanup() {
  restore || :
  if [ "$(cat "$RUN/monitor.pid" 2>/dev/null)" = "$$" ]; then
    rm -f "$RUN/active" "$RUN/heartbeat" "$RUN/ready" "$RUN/monitor.pid" "$RUN/disabled"
  fi
}

case "$1" in
  decide)
    decide "$2" "$3" "$4" "$5"
    ;;
  start)
    if [ -f "$RUN/monitor.pid" ]; then
      pid=$(cat "$RUN/monitor.pid")
      case "$pid" in ''|*[!0-9]*) ;; *) if kill -0 "$pid" 2>/dev/null && tr '\000' ' ' < "/proc/$pid/cmdline" | grep -q '/tmp/lunarpanel-charge/control-[0-9]*.sh monitor'; then exit 0; fi ;; esac
    fi
    test -r "$BAT/capacity" && test -w "$CHARGE" && test -r "$AC" || exit 1
    mkdir -p "$RUN" || exit 1
    chmod 700 "$RUN" || exit 1
    rm -f "$RUN/ready" "$RUN/active" "$RUN/heartbeat"
    runtime="$RUN/control-$$.sh"
    cp "$BASE/charge-control.sh" "$runtime" || exit 1
    sh "$runtime" monitor </dev/null >/dev/null 2>&1 &
    pid=$!
    printf '%s\n' "$pid" > "$RUN/monitor.pid"
    sh "$runtime" watch "$pid" </dev/null >/dev/null 2>&1 &
    ;;
  stop)
    if [ -f "$RUN/monitor.pid" ]; then
      pid=$(cat "$RUN/monitor.pid")
      case "$pid" in ''|*[!0-9]*) ;; *)
        if [ -r "/proc/$pid/cmdline" ] && tr '\000' ' ' < "/proc/$pid/cmdline" | grep -q '/tmp/lunarpanel-charge/control-[0-9]*.sh monitor'; then
          kill "$pid" 2>/dev/null || :
          tries=0
          while [ -r "/proc/$pid/cmdline" ] && tr '\000' ' ' < "/proc/$pid/cmdline" | grep -q '/tmp/lunarpanel-charge/control-[0-9]*.sh monitor'; do
            tries=$((tries + 1))
            if [ "$tries" -gt 10 ]; then restore || :; log 'ERROR: monitor did not stop'; exit 1; fi
            sleep 1
          done
        fi
        ;;
      esac
    fi
    restore || exit 1
    rm -f "$RUN/active" "$RUN/heartbeat" "$RUN/monitor.pid"
    ;;
  monitor)
    trap 'cleanup' EXIT
    trap 'exit 1' HUP INT TERM
    tries=0
    while [ "$(cat "$RUN/ready" 2>/dev/null)" != "$$" ]; do
      tries=$((tries + 1))
      [ "$tries" -le 10 ] || exit 1
      sleep 1
    done
    printf '%s\n' "$$" > "$RUN/active"
    log 'charge limiter started: stop at 80%, resume at 40%'
    phase=hold
    while :; do
      capacity=$(cat "$BAT/capacity") || exit 1
      online=$(cat "$AC") || exit 1
      state=$(cat "$CHARGE") || exit 1
      decision=$(decide "$capacity" "$online" "$state" "$phase") || exit 1
      action=${decision% *}
      phase=${decision#* }
      case "$action" in
        stop) printf '0\n' > "$CHARGE" || exit 1; test "$(cat "$CHARGE")" = 0 || exit 1; log "charging disabled at $capacity%" ;;
        start) printf '1\n' > "$CHARGE" || exit 1; test "$(cat "$CHARGE")" = 1 || exit 1; log "charging enabled at $capacity%" ;;
        restore) if [ -f "$RUN/disabled" ]; then restore || exit 1; rm -f "$RUN/disabled"; fi ;;
      esac
      case "$action" in stop) echo disabled > "$RUN/disabled" ;; start) rm -f "$RUN/disabled" ;; esac
      date +%s > "$RUN/heartbeat.new" && mv "$RUN/heartbeat.new" "$RUN/heartbeat" || exit 1
      sleep 10 &
      wait $!
    done
    ;;
  watch)
    pid="$2"
    printf '%s\n' "$pid" > "$RUN/ready"
    sleep 5
    while [ "$(cat "$RUN/active" 2>/dev/null)" = "$pid" ]; do
      now=$(date +%s)
      heartbeat=$(cat "$RUN/heartbeat" 2>/dev/null || echo 0)
      case "$heartbeat" in ''|*[!0-9]*) heartbeat=0 ;; esac
      if ! kill -0 "$pid" 2>/dev/null || [ "$heartbeat" -eq 0 ] || [ $((now - heartbeat)) -gt 180 ] || [ $((heartbeat - now)) -gt 300 ]; then
        log 'watchdog: monitor stopped or timed out; restoring charging'
        kill "$pid" 2>/dev/null || :
        restore || :
        if [ "$(cat "$RUN/active" 2>/dev/null)" = "$pid" ]; then
          rm -f "$RUN/active" "$RUN/heartbeat" "$RUN/ready" "$RUN/monitor.pid" "$RUN/disabled"
        fi
        exit 1
      fi
      sleep 15
    done
    if [ "$(cat "$RUN/ready" 2>/dev/null)" = "$pid" ]; then rm -f "$RUN/ready"; fi
    ;;
  *) exit 2 ;;
esac
