#!/usr/bin/env bash

set -euo pipefail
helper=/usr/local/libexec/dotfiles-power-profile-root

profile="${1:-menu}"
if [[ "$profile" == menu ]]; then
    current="$(powerprofilesctl get 2>/dev/null || printf balanced)"

    # Columns: name, detail, icon, id. The current profile is marked with a
    # leading "●", and the id is matched exactly from the last column.
    row() {
        local id="$1" icon="$2" name="$3" detail="$4" marker=''
        [[ "$id" == "$current" ]] && marker='● '
        printf '%s%s\t%s\t%b\t%s\n' "$marker" "$name" "$detail" "$icon" "$id"
    }

    selection="$({
        row power-saver '\U000f032a' 'Power saver' 'Quiet, GPU held at 55 W'
        row balanced    '\U000f0f85' 'Balanced'    'Dynamic GPU budget near 80 W'
        row performance '\U000f04c5' 'Performance' 'Dynamic Boost up to 130 W'
    } | "$HOME/.config/hypr/scripts/menu-select" -no-custom -p 'Power profile' \
        -display-columns 1 -detail-column 2 -icon-column 3)" || exit 0

    profile="${selection##*$'\t'}"
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
