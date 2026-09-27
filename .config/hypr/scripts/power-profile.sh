#!/usr/bin/env bash

set -euo pipefail
helper=/usr/local/libexec/dotfiles-power-profile-root
menu_theme="$HOME/.config/rofi/menu.rasi"

profile="${1:-menu}"
if [[ "$profile" == menu ]]; then
    current="$(powerprofilesctl get 2>/dev/null || printf balanced)"

    # "<marker> <icon>  <name padded> <detail>" reads as aligned columns because
    # the menu font is monospaced. The id travels in a hidden column so the
    # choice is matched exactly rather than by pattern.
    row() {
        local id="$1" icon="$2" name="$3" detail="$4" marker='  '
        [[ "$id" == "$current" ]] && marker=' ●'
        printf '%s %s  %-12s %s\t%s\n' "$marker" "$icon" "$name" "$detail" "$id"
    }

    selection="$({
        row power-saver '󰌪' 'Power saver' 'quiet, GPU held at 55 W'
        row balanced    '󰾅' 'Balanced'    'dynamic GPU budget near 80 W'
        row performance '󰓅' 'Performance' 'Dynamic Boost up to 130 W'
    } | rofi -dmenu -i -no-custom -p 'Power profile' -display-columns 1 \
        -theme "$menu_theme" -theme-str 'window { width: 480px; }')" || exit 0

    profile="${selection#*$'\t'}"
    [[ -n "$profile" && "$profile" != "$selection" ]] || exit 0
fi

case "$profile" in power-saver | balanced | performance) ;; *) exit 2 ;; esac
powerprofilesctl set "$profile"

if [[ -x "$helper" ]]; then
    if ! sudo -n "$helper" "$profile"; then pkexec "$helper" "$profile"; fi
fi

platform="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || printf unknown)"
gpu_limit="$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits 2>/dev/null | awk 'NR==1 {printf "%d W", $1}')"
notify-send 'Power profile changed' "$profile • platform $platform${gpu_limit:+ • GPU $gpu_limit}"
