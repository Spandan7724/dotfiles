#!/usr/bin/env bash

set -euo pipefail

if ! command -v hyprpicker >/dev/null; then
    notify-send -u critical -a 'Color Picker' "Color picker unavailable" "Install hyprpicker first."
    exit 1
fi

color="$(hyprpicker -a)" || exit 0
printf '%s' "$color" | wl-copy
notify-send -a 'Color Picker' "Color copied" "$color"
