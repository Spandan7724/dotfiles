#!/usr/bin/env bash
set -euo pipefail

# Columns: level, detail, icon, value; the value is the last column.
selection="$({
    printf '100%%\tOpaque\t\U000f00de\t1.0\n'
    printf '90%%\t\t\U000f00df\t0.9\n'
    printf '80%%\t\t\U000f00df\t0.8\n'
    printf '70%%\t\t\U000f00dd\t0.7\n'
    printf '60%%\t\t\U000f00dd\t0.6\n'
    printf '50%%\t\t\U000f00da\t0.5\n'
    printf '40%%\tGhost\t\U000f00da\t0.4\n'
} | "$HOME/.config/hypr/scripts/menu-select" -no-custom -p 'Window opacity' \
    -display-columns 1 -detail-column 2 -icon-column 3)" || exit 0

opacity="${selection##*$'\t'}"
[[ -n "$opacity" && "$opacity" != "$selection" ]] || exit 0

hyprctl dispatch "hl.dsp.window.set_prop({ prop = 'opacity', value = '$opacity override' })"
