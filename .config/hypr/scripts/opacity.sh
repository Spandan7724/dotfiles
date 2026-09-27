#!/usr/bin/env bash
set -euo pipefail
menu_theme="$HOME/.config/rofi/menu.rasi"

selection="$({
    printf '󰃞  100%%  opaque\t1.0\n'
    printf '󰃟  90%%\t0.9\n'
    printf '󰃟  80%%\t0.8\n'
    printf '󰃝  70%%\t0.7\n'
    printf '󰃝  60%%\t0.6\n'
    printf '󰃚  50%%\t0.5\n'
    printf '󰃚  40%%  ghost\t0.4\n'
} | rofi -dmenu -i -no-custom -p 'Window opacity' -display-columns 1 -theme "$menu_theme")" || exit 0

opacity="${selection#*$'\t'}"
[[ -n "$opacity" && "$opacity" != "$selection" ]] || exit 0

hyprctl dispatch "hl.dsp.window.set_prop({ prop = 'opacity', value = '$opacity override' })"
