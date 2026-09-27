#!/usr/bin/env bash

set -euo pipefail

expression="$(printf '' | rofi -dmenu -p 'Calculate' -theme "$HOME/.config/rofi/input.rasi")"
[[ -n "$expression" ]] || exit 0

if ! command -v qalc >/dev/null; then
    notify-send -u critical -a Calculator "Calculator unavailable" "Install libqalculate first."
    exit 1
fi

result="$(qalc -t "$expression" 2>/dev/null | tail -n 1)"
printf '%s' "$result" | wl-copy
notify-send -a Calculator "$expression" "$result copied to the clipboard."
