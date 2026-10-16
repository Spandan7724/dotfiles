#!/usr/bin/env bash

set -euo pipefail
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
themes_root="$config_root/themes"

current=""
[[ -L "$themes_root/current" ]] && current="$(basename "$(readlink "$themes_root/current")")"

icon_for() {
    case "$1" in
        *light*) printf '\U000f05a8' ;;
        wallpaper*) printf '\U000f0e09' ;;
        *) printf '\U000f03d8' ;;
    esac
}

# A theme's palette preview: background, foreground, accent, and four of its
# terminal colours, read from its colors.toml.
swatches_for() {
    local key colors=()
    for key in background foreground accent red yellow green magenta; do
        colors+=("$(sed -nE "s/^${key}[[:space:]]*=[[:space:]]*\"(#[0-9A-Fa-f]{6})\".*/\1/p" "$themes_root/$1/colors.toml" 2>/dev/null | head -1)")
    done
    printf '%s ' "${colors[@]}"
}

# Columns: label, detail, icon, palette swatches, directory name. The
# directory name is the last column, so the visible label is free to be
# prettified; the current theme is marked with a leading "●".
selection="$({
    while IFS= read -r name; do
        label="$(printf '%s' "$name" | sed -E 's/-/ /g; s/(^| )([a-z])/\1\U\2/g')"
        marker=''
        [[ "$name" == "$current" ]] && marker='● '
        case "$name" in *light*) detail='Light' ;; wallpaper*) detail='Colours from the wallpaper' ;; *) detail='Dark' ;; esac
        printf '%s%s\t%s\t%s\t%s\t%s\n' "$marker" "$label" "$detail" "$(icon_for "$name")" "$(swatches_for "$name")" "$name"
    done < <(find "$themes_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
} | "$HOME/.config/hypr/scripts/menu-select" -no-custom -p 'Theme' \
    -display-columns 1 -detail-column 2 -icon-column 3 -swatch-column 4)" || exit 0

theme="${selection##*$'\t'}"
[[ -n "$theme" && "$theme" != "$selection" ]] || exit 0

exec "$themes_root/apply.sh" "$theme"
