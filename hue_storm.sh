#!/bin/bash

ROOM="Office"
MAGENTA="#FE029A"
CYAN="#00F3FF"
ACCENT="#0D0121"

BASE_BRI=50
ACCENT_BRI=$(( BASE_BRI * 60 / 100 ))

STRIKE_T=(--transition-time 0.05s)
DECAY_T=(--transition-time 1.5s)
ROLL_T=(--transition-time 3.0s)
BASE_T=(--transition-time 0.5s)

PID_FILE="/tmp/hue_storm.pid"
DBUS_PID_FILE="/tmp/hue_dbus.pid"
SUSPEND_FLAG="/tmp/hue_storm_suspended"

i_sleep() {
    read -r -t "$1" 2>/dev/null || true
}

singleton_check() {
    if [[ -f "$PID_FILE" ]]; then
        OLD_PID=$(cat "$PID_FILE")
        if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Active storm detected. Terminating process PID: $OLD_PID..."
            kill -SIGTERM "$OLD_PID" 2>/dev/null
            while kill -0 "$OLD_PID" 2>/dev/null; do
                i_sleep 0.1
            done
        fi
    fi
}

monitor_bus() {
    gdbus monitor --session --dest org.freedesktop.ScreenSaver --object-path /ScreenSaver | while read -r line; do
        if echo "$line" | grep -q "ActiveChanged (true,)"; then
            touch "$SUSPEND_FLAG"
            openhue set light --room "$ROOM" "Office" --off
            openhue set light --room "$ROOM" "Hue Play 1" --off
            openhue set light --room "$ROOM" "Hue Play 2" --off
        elif echo "$line" | grep -q "ActiveChanged (false,)"; then
            rm -f "$SUSPEND_FLAG"
            openhue set light --room "$ROOM" "Office" --on --rgb "$MAGENTA" --brightness "$BASE_BRI" "${BASE_T[@]}"
            openhue set light --room "$ROOM" "Hue Play 1" --on --rgb "$ACCENT" --brightness "$ACCENT_BRI" "${BASE_T[@]}"
            openhue set light --room "$ROOM" "Hue Play 2" --on --rgb "$MAGENTA" --brightness "$BASE_BRI" "${BASE_T[@]}"
        fi
    done
}

lock_base() {
    SPARK_ENABLED=false
    echo "Storm dissipating... Base colors locked."
}

energize_storm() {
    SPARK_ENABLED=true
    echo "Magneta storm energized."
}

power_off() {
    trap - SIGINT SIGTERM EXIT
    [[ -f "$DBUS_PID_FILE" ]] && kill "$(cat "$DBUS_PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE" "$SUSPEND_FLAG" "$DBUS_PID_FILE"
    echo "Storm dissipated. Lights powering off."
    openhue set light --room "$ROOM" "Office" --off "${BASE_T[@]}"
    openhue set light --room "$ROOM" "Hue Play 1" --off "${BASE_T[@]}"
    openhue set light --room "$ROOM" "Hue Play 2" --off "${BASE_T[@]}"
    exit 0
}

cleanup() {
    trap - SIGINT SIGTERM EXIT
    [[ -f "$DBUS_PID_FILE" ]] && kill "$(cat "$DBUS_PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE" "$SUSPEND_FLAG" "$DBUS_PID_FILE"
    echo -e "\nMagneta Storm dissipating. Reverting to default state..."
    openhue set light --room "$ROOM" "Office" --on --rgb "$MAGENTA" --brightness "$BASE_BRI" "${BASE_T[@]}"
    openhue set light --room "$ROOM" "Hue Play 1" --on --rgb "$ACCENT" --brightness "$ACCENT_BRI" "${BASE_T[@]}"
    openhue set light --room "$ROOM" "Hue Play 2" --on --rgb "$MAGENTA" --brightness "$BASE_BRI" "${BASE_T[@]}"
    exit 0
}

if [[ "$1" == "solid" ]]; then
    [[ -f "$PID_FILE" ]] && kill -SIGUSR1 "$(cat "$PID_FILE")" || echo "Storm process not found."
    exit 0
elif [[ "$1" == "storm" ]]; then
    [[ -f "$PID_FILE" ]] && kill -SIGUSR2 "$(cat "$PID_FILE")" || echo "Storm process not found."
    exit 0
elif [[ "$1" == "stop" ]]; then
    [[ -f "$PID_FILE" ]] && kill -SIGALRM "$(cat "$PID_FILE")" || echo "Storm process not found."
    exit 0
elif [[ "$1" != "--daemon" ]]; then
    singleton_check
    echo "Storm rolling in the background..."
    nohup "$0" --daemon >/dev/null 2>&1 &
    exit 0
fi

echo $$ > "$PID_FILE"
SPARK_ENABLED=true
trap lock_base SIGUSR1
trap energize_storm SIGUSR2
trap power_off SIGALRM
trap cleanup SIGINT SIGTERM EXIT

monitor_bus &
echo $! > "$DBUS_PID_FILE"

openhue set light --room "$ROOM" "Office" --on --rgb "$MAGENTA" --brightness "$BASE_BRI"
openhue set light --room "$ROOM" "Hue Play 1" --on --rgb "$ACCENT" --brightness "$ACCENT_BRI"
openhue set light --room "$ROOM" "Hue Play 2" --on --rgb "$MAGENTA" --brightness "$BASE_BRI"

while true; do
    if [[ -f "$SUSPEND_FLAG" ]]; then
        i_sleep 1
        continue
    fi

    VARIANCE=$(( RANDOM % 31 - 15 ))
    CURRENT_ROLL=$(( BASE_BRI + VARIANCE ))

    openhue set light --room "$ROOM" "Office" --rgb "$MAGENTA" --brightness "$CURRENT_ROLL" "${ROLL_T[@]}" &
    openhue set light --room "$ROOM" "Hue Play 2" --rgb "$MAGENTA" --brightness "$CURRENT_ROLL" "${ROLL_T[@]}" &

    WAIT_TIME=$(( RANDOM % 10 + 3 ))
    i_sleep "$WAIT_TIME"

    if [[ -f "$SUSPEND_FLAG" ]]; then continue; fi

    if [[ "$SPARK_ENABLED" == true ]] && (( RANDOM % 100 < 35 )); then
        STRIKE_BRI=$(( BASE_BRI * 2 ))
        (( STRIKE_BRI > 100 )) && STRIKE_BRI=100

        if (( RANDOM % 100 < 80 )); then
            openhue set light --room "$ROOM" "Hue Play 1" --rgb "$CYAN" --brightness "$STRIKE_BRI" "${STRIKE_T[@]}"
        fi
        if (( RANDOM % 100 < 80 )); then
            openhue set light --room "$ROOM" "Hue Play 2" --rgb "$CYAN" --brightness "$STRIKE_BRI" "${STRIKE_T[@]}"
        fi

        i_sleep 0.1

        openhue set light --room "$ROOM" "Hue Play 1" --rgb "$ACCENT" --brightness "$ACCENT_BRI" "${DECAY_T[@]}"
        openhue set light --room "$ROOM" "Hue Play 2" --rgb "$MAGENTA" --brightness "$CURRENT_ROLL" "${DECAY_T[@]}"

        if (( RANDOM % 100 < 25 )); then
            i_sleep 0.4
            openhue set light --room "$ROOM" "Hue Play 1" --rgb "$CYAN" --brightness "$STRIKE_BRI" "${STRIKE_T[@]}"
            openhue set light --room "$ROOM" "Hue Play 2" --rgb "$CYAN" --brightness "$STRIKE_BRI" "${STRIKE_T[@]}"
            i_sleep 0.1
            openhue set light --room "$ROOM" "Hue Play 1" --rgb "$ACCENT" --brightness "$ACCENT_BRI" "${DECAY_T[@]}"
            openhue set light --room "$ROOM" "Hue Play 2" --rgb "$MAGENTA" --brightness "$CURRENT_ROLL" "${DECAY_T[@]}"
        fi
    fi
done
