#!/usr/bin/env bash
# Clamshell mode: with the lid closed and an external display connected, turn
# the laptop panel off so windows and workspaces move to the external one; turn
# it back on when the lid opens or the last external display goes away.
#
#   lid.sh sync    apply the current lid and display state (lid switch binds)
#   lid.sh watch   sync now and on every monitor hotplug (started at login)
#
# An undocked lid close is left to logind, which suspends; logind ignores the
# lid while an external display is connected (HandleLidSwitchDocked=ignore).
# Runtime only: nothing is written to disk; `hyprctl reload` restores the panel
# from machine.lua, and this re-applies clamshell on the next event.

set -uo pipefail

lid_closed() {
    local state
    for state in /proc/acpi/button/lid/*/state; do
        [[ -r "$state" ]] && grep -q closed "$state" && return 0
    done
    return 1
}

monitors_json() { hyprctl -j monitors all 2>/dev/null; }

internal_name() {
    jq -r '[.[] | select(.name | test("^(eDP|LVDS|DSI)-"))][0].name // empty'
}

# Any enabled display other than the panel (and Hyprland's FALLBACK output).
external_enabled() {
    jq -e --arg internal "$1" \
        'any(.[]; .name != $internal and .name != "FALLBACK" and (.disabled | not))' >/dev/null
}

internal_disabled() {
    jq -e --arg internal "$1" 'any(.[]; .name == $internal and .disabled == true)' >/dev/null
}

sync() {
    local json internal
    json="$(monitors_json)" || return 0
    internal="$(internal_name <<<"$json")"
    [[ "$internal" =~ ^[A-Za-z0-9._-]+$ ]] || return 0

    if lid_closed && external_enabled "$internal" <<<"$json"; then
        internal_disabled "$internal" <<<"$json" && return 0
        hyprctl eval "hl.monitor({ output = \"$internal\", disabled = true })" >/dev/null 2>&1
    elif internal_disabled "$internal" <<<"$json"; then
        # Re-read the config, which brings the panel back with its machine.lua
        # mode, then let power-watch.sh re-apply the battery refresh rate.
        hyprctl reload >/dev/null 2>&1
        local pid
        pid="$(cat "${XDG_RUNTIME_DIR:-/tmp}/hypr-power-watch.pid" 2>/dev/null)"
        [[ "$pid" =~ ^[0-9]+$ ]] && kill -USR1 "$pid" 2>/dev/null
    fi
}

watch() {
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-lid-watch.lock"
    flock -n 9 || exit 0
    local socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    sync
    socat -U - "UNIX-CONNECT:$socket" 2>/dev/null | while IFS= read -r event; do
        case "$event" in
            monitoradded* | monitorremoved*)
                # Give the new output a moment to finish its modeset.
                sleep 1
                sync
                ;;
        esac
    done
}

case "${1:-sync}" in
    sync) sync ;;
    watch) watch ;;
    *) printf 'Usage: %s [sync|watch]\n' "$0" >&2; exit 2 ;;
esac
