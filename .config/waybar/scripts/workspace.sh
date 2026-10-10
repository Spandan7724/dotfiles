#!/usr/bin/env bash
# One clickable workspace button for Waybar (custom/ws1 .. custom/ws10 and
# custom/ws-special). Waybar's hyprland/workspaces module switches workspaces
# with the legacy `dispatch workspace N` IPC call, which Hyprland's Lua config
# rejects, so its buttons cannot be clicked. These buttons focus workspaces
# with hl.dsp instead.
#
#   workspace.sh <1-10|special>          print this button's JSON (rendered
#                                        by workspace-watch.sh)
#   workspace.sh focus <1-10|special>    switch to it

set -euo pipefail

if [[ "${1:-}" == focus ]]; then
    target="${2:?workspace required}"
    if [[ "$target" == special ]]; then
        hyprctl dispatch 'hl.dsp.workspace.toggle_special("scratchpad")' >/dev/null
    elif [[ "$target" =~ ^[0-9]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ workspace = $target })" >/dev/null
    fi
    exit 0
fi

id="${1:?workspace required}"
# workspace-watch.sh renders every button once per change; just read ours.
cat -- "${XDG_RUNTIME_DIR}/waybar-workspaces/$id.json" 2>/dev/null || printf '{"text":""}\n'
