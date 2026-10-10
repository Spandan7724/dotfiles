#!/usr/bin/env bash

set -euo pipefail

expression="$(printf '' | "$HOME/.config/hypr/scripts/menu-select" -p 'Calculator' -placeholder 'An expression, e.g. 12% of 340 or 5 km to miles')"
[[ -n "$expression" ]] || exit 0

if ! command -v qalc >/dev/null; then
    notify-send -u critical -a Calculator "Calculator unavailable" "Install libqalculate first."
    exit 1
fi

result="$(qalc -t "$expression" 2>/dev/null | tail -n 1)"
printf '%s' "$result" | wl-copy
notify-send -a Calculator "$expression" "$result copied to the clipboard."
