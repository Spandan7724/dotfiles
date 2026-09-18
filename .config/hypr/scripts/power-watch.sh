#!/usr/bin/env bash

# Drop the internal panel to 60 Hz on battery and restore its highest refresh
# rate on AC. A 3200x2000 panel at 165 Hz is the single largest display power
# draw on this machine, and the compositor is the only component that can
# change the mode.
#
# Runtime only: this evaluates `hl.monitor(...)` in the running compositor, so
# nothing is written to disk and a `hyprctl reload` returns to machine.lua.
# Docs: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/

set -uo pipefail

readonly BATTERY_REFRESH=60
readonly POLL_SECONDS=5

ac_online() {
    local supply type
    for supply in /sys/class/power_supply/*; do
        [[ -r "$supply/type" && -r "$supply/online" ]] || continue
        type="$(<"$supply/type")"
        [[ "$type" != "Battery" && "$type" != "Unknown" ]] || continue
        [[ "$(<"$supply/online")" == "1" ]] && return 0
    done
    return 1
}

has_mains() {
    local supply type
    for supply in /sys/class/power_supply/*; do
        [[ -r "$supply/type" && -r "$supply/online" ]] || continue
        type="$(<"$supply/type")"
        [[ "$type" != "Battery" && "$type" != "Unknown" ]] && return 0
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

# Refresh rates available at the panel's current resolution.
available_refreshes_for() {
    local name="$1" resolution="$2"
    hyprctl -j monitors all 2>/dev/null | jq -r --arg name "$name" --arg res "$resolution" '
        .[] | select(.name == $name) | .availableModes[]?
        | select(startswith($res + "@"))
        | split("@")[1] | sub("Hz$"; "") | tonumber'
}

# Highest refresh rate available at the panel's current resolution.
best_refresh_for() {
    available_refreshes_for "$1" "$2" | sort -gr | head -n 1
}

# Use the advertised mode closest to 60 Hz instead of assuming the EDID calls
# it exactly 60. Panels commonly expose values such as 59.94 or 60.01.
battery_refresh_for() {
    available_refreshes_for "$1" "$2" | awk -v target="$BATTERY_REFRESH" '
        BEGIN { best_delta = -1 }
        {
            delta = $1 - target
            if (delta < 0) delta = -delta
            if (best_delta < 0 || delta < best_delta) {
                best = $1
                best_delta = delta
            }
        }
        END { if (best_delta >= 0) print best }
    '
}

apply_refresh() {
    local target_refresh="$1"
    local name resolution position scale

    IFS=$'\t' read -r name resolution position scale < <(internal_monitor) || return
    [[ -n "${name:-}" && -n "${resolution:-}" ]] || return
    [[ "$name" =~ ^[A-Za-z0-9._:-]+$ ]] || return
    [[ "$resolution" =~ ^[0-9]+x[0-9]+$ ]] || return
    [[ "$position" =~ ^-?[0-9]+x-?[0-9]+$ ]] || return
    [[ "$scale" =~ ^[0-9]+([.][0-9]+)?$ ]] || return
    [[ "$target_refresh" =~ ^[0-9]+([.][0-9]+)?$ ]] || return

    hyprctl eval \
        "hl.monitor({ output = \"$name\", mode = \"${resolution}@${target_refresh}\", position = \"$position\", scale = $scale })" \
        >/dev/null 2>&1
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
        refresh=""
        name=""
        resolution=""
        IFS=$'\t' read -r name resolution _ _ < <(internal_monitor) || true

        if [[ "$state" == "ac" ]]; then
            if [[ -n "${name:-}" && -n "${resolution:-}" ]]; then
                refresh="$(best_refresh_for "$name" "$resolution")"
            fi
        else
            if [[ -n "${name:-}" && -n "${resolution:-}" ]]; then
                refresh="$(battery_refresh_for "$name" "$resolution")"
            fi
        fi

        # Do not record the transition unless the monitor change succeeded.
        # This makes startup races and temporary compositor errors retry on the
        # next poll instead of remaining stuck until the charger state changes.
        if [[ -n "$refresh" ]] && apply_refresh "$refresh"; then
            last_state="$state"
        fi
    fi

    sleep "$POLL_SECONDS"
done
