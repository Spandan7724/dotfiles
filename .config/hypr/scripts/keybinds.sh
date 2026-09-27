#!/usr/bin/env bash

set -euo pipefail

format_key() {
    local mask="$1" key="$2" parts=() part joined
    ((mask & 64)) && parts+=(Super)
    ((mask & 8)) && parts+=(Alt)
    ((mask & 4)) && parts+=(Ctrl)
    ((mask & 1)) && parts+=(Shift)
    case "${key,,}" in
        mouse:272) key="Left mouse" ;; mouse:273) key="Right mouse" ;;
        mouse_down) key="Wheel down" ;; mouse_up) key="Wheel up" ;;
        return) key="Enter" ;; grave) key='`' ;; slash) key='/' ;; backslash) key='\\' ;;
        bracketleft) key='[' ;; bracketright) key=']' ;; semicolon) key=';' ;;
        comma) key=',' ;; period) key='.' ;; equal) key='=' ;; minus) key='-' ;;
        space) key='Space' ;; page_up) key='Page Up' ;; page_down) key='Page Down' ;;
        left) key='Left' ;; right) key='Right' ;; up) key='Up' ;; down) key='Down' ;;
    esac
    parts+=("$key")
    joined="${parts[0]}"
    for part in "${parts[@]:1}"; do joined+=" + $part"; done
    printf '%s' "$joined"
}

icon_for() {
    case "${1,,}" in
        *workspace*|*monitor*) printf '󰍹' ;; *window*|*floating*|*fullscreen*|*split*|*tile*) printf '󰖯' ;;
        *capture*|*screenshot*|*record*|*color*) printf '󰄀' ;; *volume*|*audio*|*media*|*microphone*) printf '󰕾' ;;
        *clipboard*) printf '󰅌' ;; *wallpaper*|*theme*) printf '󰏘' ;; *lock*|*session*|*power*) printf '󰌾' ;;
        *search*|*open*|*choose*) printf '󰍉' ;; *) printf '󰌌' ;;
    esac
}

rows="$({
    printf '%s  %-27s %s\n' '󰍹' 'Super + 1…0' 'Switch to workspace 1…10'
    printf '%s  %-27s %s\n' '󰍹' 'Super + Shift + 1…0' 'Move window and follow to workspace'
    printf '%s  %-27s %s\n' '󰍹' 'Super + Ctrl + 1…0' 'Move window silently to workspace'
    while IFS=$'\t' read -r mask key description submap; do
        [[ "$mask" =~ ^[0-9]+$ ]] || continue
        ((mask > 0)) || continue
        [[ -n "$description" && -z "$submap" ]] || continue
        [[ "$key" != XF86* ]] || continue
        if [[ "$key" =~ ^[0-9]$ && "$description" =~ workspace\ [0-9]+$ ]]; then continue; fi
        printf '%s  %-27s %s\n' "$(icon_for "$description")" "$(format_key "$mask" "$key")" "$description"
    done < <(hyprctl binds -j | jq -r '.[] | [.modmask, .key, .description, .submap] | @tsv')
} | awk '!seen[$0]++' | sort -f -k3)"

[[ -n "$rows" ]] || { notify-send 'Keybindings' 'Hyprland returned no described shortcuts.'; exit 1; }
printf '%s\n' "$rows" | rofi -dmenu -i -no-custom -p 'Keybindings' \
    -mesg 'Hardware media keys are hidden' \
    -theme "$HOME/.config/rofi/keybinds.rasi"
