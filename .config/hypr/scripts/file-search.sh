#!/usr/bin/env bash

set -euo pipefail

selection="$(find "$HOME" \
    -path "$HOME/.cache" -prune -o \
    -path "$HOME/.local/share/Trash" -prune -o \
    -path "$HOME/.git" -prune -o \
    -type f -printf '%P\n' 2>/dev/null | rofi -dmenu -i -p 'Files' -theme-str 'window { width: 640px; } listview { lines: 12; }')"

[[ -n "$selection" ]] || exit 0
xdg-open "$HOME/$selection" >/dev/null 2>&1 &
