#!/usr/bin/env bash

set -euo pipefail

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
themes_root="$config_root/themes"

theme="$({
    find "$themes_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
} | sort | rofi -dmenu -p 'Theme')"

[[ -n "$theme" ]] || exit 0
exec "$themes_root/apply.sh" "$theme"
