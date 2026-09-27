#!/usr/bin/env bash

set -euo pipefail
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
themes_root="$config_root/themes"
menu_theme="$config_root/rofi/menu.rasi"

current=""
[[ -L "$themes_root/current" ]] && current="$(basename "$(readlink "$themes_root/current")")"

icon_for() {
    case "$1" in
        *light*) printf '󰖨' ;;
        wallpaper*) printf '󰸉' ;;
        *) printf '󰏘' ;;
    esac
}

# The directory name travels in a hidden column, so the visible label is free
# to be prettified without the selection having to be parsed back out of it.
selection="$({
    while IFS= read -r name; do
        label="$(printf '%s' "$name" | sed -E 's/-/ /g; s/(^| )([a-z])/\1\U\2/g')"
        marker='  '
        [[ "$name" == "$current" ]] && marker=' ●'
        printf '%s %s  %s\t%s\n' "$marker" "$(icon_for "$name")" "$label" "$name"
    done < <(find "$themes_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
} | rofi -dmenu -i -no-custom -p 'Theme' -display-columns 1 -theme "$menu_theme")" || exit 0

theme="${selection#*$'\t'}"
[[ -n "$theme" && "$theme" != "$selection" ]] || exit 0

exec "$themes_root/apply.sh" "$theme"
