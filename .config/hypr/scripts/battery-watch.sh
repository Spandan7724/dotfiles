#!/usr/bin/env bash
# Low-battery notifications at 20%, 10% and 5% while discharging (Waybar only
# changes colour). Each level fires once per discharge; plugging in resets
# them. Started from hyprland.lua.

set -uo pipefail

readonly LEVELS=(20 10 5)
readonly POLL_SECONDS=60

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-battery-watch.lock"
flock -n 9 || exit 0

batteries=()
for supply in /sys/class/power_supply/*; do
    [[ -r "$supply/type" && "$(<"$supply/type")" == Battery && -r "$supply/capacity" ]] \
        && batteries+=("$supply")
done
((${#batteries[@]})) || exit 0

declare -A notified
notification_id=0

while true; do
    capacity_sum=0 discharging=0
    for battery in "${batteries[@]}"; do
        capacity_sum=$((capacity_sum + $(<"$battery/capacity")))
        [[ "$(<"$battery/status")" == Discharging ]] && discharging=1
    done
    capacity=$((capacity_sum / ${#batteries[@]}))

    if ((!discharging)); then
        notified=()
        if ((notification_id)); then
            # Take a lingering critical warning down once the charger is in.
            gdbus call --session --dest org.freedesktop.Notifications \
                --object-path /org/freedesktop/Notifications \
                --method org.freedesktop.Notifications.CloseNotification "$notification_id" >/dev/null 2>&1
            notification_id=0
        fi
    else
        # The lowest level already crossed; higher ones count as announced too,
        # so starting up at 8% gives one warning, not three.
        for ((i = ${#LEVELS[@]} - 1; i >= 0; i--)); do
            level="${LEVELS[i]}"
            ((capacity <= level)) || continue
            [[ -n "${notified[$level]:-}" ]] && break
            for higher in "${LEVELS[@]}"; do ((higher >= level)) && notified[$higher]=1; done
            if ((level <= 10)); then
                urgency=critical body="Plug in now."
            else
                urgency=normal body="Plug in soon."
            fi
            notification_id="$(notify-send --app-name=battery --urgency="$urgency" \
                --icon=battery-caution --print-id ${notification_id:+--replace-id="$notification_id"} \
                "Battery low: ${capacity}%" "$body" 2>/dev/null || echo 0)"
            break
        done
    fi
    sleep "$POLL_SECONDS"
done
