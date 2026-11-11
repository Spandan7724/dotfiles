#!/usr/bin/env bash
# Night light through hyprsunset. hyprsunset applies a colour matrix in the
# compositor, so it changes smoothly and never flickers.
#
#   nightlight.sh toggle | on | off | warmer | cooler | status
#
# The temperature is remembered in ~/.local/state/dotfiles/nightlight; scroll
# on the bar icon to make it warmer or cooler while it is on.

set -uo pipefail

readonly DEFAULT_TEMP=4000 MIN_TEMP=2500 MAX_TEMP=5500 STEP=250
state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/nightlight"

saved_temp() {
    local temp
    temp="$(cat "$state" 2>/dev/null)"
    [[ "$temp" =~ ^[0-9]+$ ]] && ((temp >= MIN_TEMP && temp <= MAX_TEMP)) || temp="$DEFAULT_TEMP"
    printf '%s\n' "$temp"
}

current_temp() {
    hyprctl hyprsunset temperature 2>/dev/null | grep -oE '[0-9]+' | head -n1
}

# hyprsunset reports 6000 K and up as off: identity resets it to 6500 K.
is_on() {
    local temp
    temp="$(current_temp)"
    [[ -n "$temp" ]] && ((temp < 6000))
}

ensure_running() {
    pgrep -x hyprsunset >/dev/null && return 0
    setsid hyprsunset >/dev/null 2>&1 &
    # A fresh hyprsunset applies its profile as it finishes starting.
    for _ in {1..20}; do
        hyprctl hyprsunset temperature >/dev/null 2>&1 && { sleep 0.3; return 0; }
        sleep 0.1
    done
    return 1
}

set_temp() {
    local temp="$1"
    mkdir -p "$(dirname "$state")"
    printf '%s\n' "$temp" >"$state"
    hyprctl hyprsunset temperature "$temp" >/dev/null 2>&1
}

refresh_bar() { pkill -RTMIN+12 -x waybar 2>/dev/null || true; }

case "${1:-status}" in
    status)
        if is_on; then
            printf '{"text":"󰖔","tooltip":"Night light on (%s K)\\nScroll to adjust","class":"enabled"}\n' "$(current_temp)"
        else
            printf '{"text":"󰖨","tooltip":"Night light off","class":"disabled"}\n'
        fi
        exit 0
        ;;
    on) ensure_running && set_temp "$(saved_temp)" ;;
    off) ensure_running && hyprctl hyprsunset identity >/dev/null 2>&1 ;;
    toggle)
        ensure_running || exit 1
        if is_on; then
            hyprctl hyprsunset identity >/dev/null 2>&1
        else
            set_temp "$(saved_temp)"
        fi
        ;;
    warmer | cooler)
        is_on || exit 0
        temp="$(saved_temp)"
        [[ "$1" == warmer ]] && temp=$((temp - STEP)) || temp=$((temp + STEP))
        ((temp < MIN_TEMP)) && temp="$MIN_TEMP"
        ((temp > MAX_TEMP)) && temp="$MAX_TEMP"
        set_temp "$temp"
        ;;
    *) printf 'Usage: %s toggle|on|off|warmer|cooler|status\n' "$0" >&2; exit 2 ;;
esac
refresh_bar
