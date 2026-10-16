#!/usr/bin/env bash
# An icon for the Win+H music scratchpad, including terminal music players.
set -euo pipefail

case "${1:-status}" in
    status)
        clients="$(hyprctl -j clients 2>/dev/null)" || clients='[]'
        jq -c '
            [.[] | select(.workspace.name == "special:ncspot" or .class == "dotfiles-ncspot")][0] as $music |
            if $music == null then {text: ""}
            else {
                text: "󰎆",
                class: "running",
                tooltip: (($music.title // "Music player") + "\n\nClick: show/hide music scratchpad (Win+H)")
            } end
        ' <<<"$clients"
        ;;
    toggle)
        exec hyprctl dispatch 'hl.dsp.workspace.toggle_special("ncspot")'
        ;;
    *) exit 2 ;;
esac
