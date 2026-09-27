#!/usr/bin/env bash

set -euo pipefail

mode="${1:-area}"
directory="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$directory"
output="$directory/$(date '+%Y-%m-%d_%H-%M-%S').png"
geometry=""

case "$mode" in
    area|area-copy|annotate|ocr)
        geometry="$(slurp)" || exit 0
        ;;
    window)
        geometry="$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        ;;
    delay)
        sleep 5
        ;;
    full) ;;
    *) exit 2 ;;
esac

if [[ "$mode" == area-copy ]]; then
    grim -g "$geometry" - | wl-copy
    notify-send -a Screenshot "Screenshot copied" "The selected region is in the clipboard."
    exit 0
fi

if [[ -n "$geometry" ]]; then
    grim -g "$geometry" "$output"
else
    grim "$output"
fi

if [[ "$mode" == annotate ]] && command -v swappy >/dev/null; then
    swappy -f "$output"
elif [[ "$mode" == ocr ]] && command -v tesseract >/dev/null; then
    tesseract "$output" stdout | wl-copy
    notify-send -a Screenshot "Text copied" "OCR output is in the clipboard."
    exit 0
fi

notify-send -a Screenshot -i "$output" "Screenshot saved" "$output"
