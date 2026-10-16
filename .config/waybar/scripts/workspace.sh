#!/usr/bin/env bash
# One clickable workspace button for Waybar (custom/ws1 .. custom/ws20,
# custom/wsnamed1 .. custom/wsnamed5, and custom/ws-special). Waybar's
# hyprland/workspaces module switches workspaces with the legacy
# `dispatch workspace N` IPC call, which Hyprland's Lua config rejects, so its
# buttons cannot be clicked. These buttons focus workspaces with hl.dsp instead.
#
#   workspace.sh <1-20|named1-5|special>         print this button's JSON
#                                                (rendered by workspace-watch.sh)
#   workspace.sh focus <1-20|named1-5|special>   switch to it

set -euo pipefail

if [[ "${1:-}" == focus ]]; then
    target="${2:?workspace required}"
    if [[ "$target" == special ]]; then
        hyprctl dispatch 'hl.dsp.workspace.toggle_special("scratchpad")' >/dev/null
    elif [[ "$target" =~ ^[0-9]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ workspace = $target })" >/dev/null
    elif [[ "$target" =~ ^named[0-9]+$ ]]; then
        # The slot's JSON carries the workspace name in "alt".
        name="$(jq -r '.alt // empty' "${XDG_RUNTIME_DIR}/waybar-workspaces/$target.json" 2>/dev/null)"
        if [[ "$name" =~ ^[[:alnum:]\ _.-]+$ ]]; then
            hyprctl dispatch "hl.dsp.focus({ workspace = \"name:$name\" })" >/dev/null
        fi
    fi
    exit 0
fi

id="${1:?workspace required}"
# workspace-watch.sh renders every button once per change; just read ours.
cat -- "${XDG_RUNTIME_DIR}/waybar-workspaces/$id.json" 2>/dev/null || printf '{"text":""}\n'
