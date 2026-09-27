#!/usr/bin/env bash

set -euo pipefail

wallpaper_dir="$HOME/Pictures/Wallpapers"
state_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-wallpaper"

mapfile -d '' wallpapers < <(find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    -print0 | sort -z)

((${#wallpapers[@]} > 0)) || exit 1

case "${1:-random}" in
    random)
        index=$((RANDOM % ${#wallpapers[@]}))
        ;;
    next|previous)
        current=""
        [[ -r "$state_file" ]] && current="$(<"$state_file")"
        index=0
        for i in "${!wallpapers[@]}"; do
            [[ "${wallpapers[$i]}" == "$current" ]] && index="$i"
        done
        if [[ "$1" == next ]]; then
            index=$(((index + 1) % ${#wallpapers[@]}))
        else
            index=$(((index - 1 + ${#wallpapers[@]}) % ${#wallpapers[@]}))
        fi
        ;;
    *) exit 2 ;;
esac

mkdir -p "$(dirname "$state_file")"
printf '%s\n' "${wallpapers[$index]}" >"$state_file"
"$HOME/.config/themes/wallpaper.sh" "${wallpapers[$index]}"
