#!/usr/bin/env bash

# Drop the internal panel to 60 Hz on battery and restore its highest refresh
# rate on AC. A 3200x2000 panel at 165 Hz is the single largest display power
# draw on this machine, and the compositor is the only component that can
# change the mode.
#
# Runtime only: this uses `hyprctl keyword`, so nothing is written to disk and a
# `hyprctl reload` returns to the mode in machine.lua.
# Docs: https://wiki.hypr.land/Configuring/Using-hyprctl/

set -uo pipefail

readonly BATTERY_REFRESH=60
readonly POLL_SECONDS=5

ac_online() {
    local supply
    for supply in /sys/class/power_supply/*; do
        [[ -r "$supply/type" && -r "$supply/online" ]] || continue
        [[ "$(<"$supply/type")" == "Mains" ]] || continue
        [[ "$(<"$supply/online")" == "1" ]] && return 0
    done
    return 1
}

has_mains() {
    local supply
    for supply in /sys/class/power_supply/*; do
        [[ -r "$supply/type" ]] || continue
        [[ "$(<"$supply/type")" == "Mains" ]] && return 0
    done
    return 1
}

# Echoes "name mode position scale" for the internal panel, or nothing.
internal_monitor() {
    hyprctl -j monitors all 2>/dev/null | jq -r '
        [ .[] | select(.name | test("^(eDP|LVDS|DSI)-")) ] as $internal
        | ($internal[0] // .[0])
        | select(. != null)
        | [ .name,
            (.width | tostring) + "x" + (.height | tostring),
            (.x | tostring) + "x" + (.y | tostring),
            (.scale | tostring)
          ] | @tsv'
}

# Highest refresh rate available at the panel's current resolution.
best_refresh_for() {
    local name="$1" resolution="$2"
    hyprctl -j monitors all 2>/dev/null | jq -r --arg name "$name" --arg res "$resolution" '
        .[] | select(.name == $name) | .availableModes[]?
        | select(startswith($res + "@"))
        | split("@")[1] | sub("Hz$"; "") | tonumber' \
        | sort -gr | head -n 1
}

apply_refresh() {
    local target_refresh="$1"
    local name resolution position scale

    IFS=$'\t' read -r name resolution position scale < <(internal_monitor) || return
    [[ -n "${name:-}" && -n "${resolution:-}" ]] || return

    hyprctl keyword monitor \
        "$name,${resolution}@${target_refresh},${position},${scale}" >/dev/null 2>&1
}

command -v hyprctl >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Only one watcher may run: two loops would fight over the monitor mode if the
# script is ever started again by hand alongside the session's own instance.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-power-watch.lock"
flock -n 9 || exit 0

# A machine with no mains supply is a desktop; there is nothing to switch.
has_mains || exit 0

last_state=""
while true; do
    if ac_online; then
        state="ac"
    else
        state="battery"
    fi

    if [[ "$state" != "$last_state" ]]; then
        if [[ "$state" == "ac" ]]; then
            name=""
            resolution=""
            IFS=$'\t' read -r name resolution _ _ < <(internal_monitor) || true
            refresh=""
            if [[ -n "${name:-}" && -n "${resolution:-}" ]]; then
                refresh="$(best_refresh_for "$name" "$resolution")"
            fi
            [[ -n "$refresh" ]] && apply_refresh "$refresh"
        else
            apply_refresh "$BATTERY_REFRESH"
        fi
        last_state="$state"
    fi

    sleep "$POLL_SECONDS"
done
