#!/usr/bin/env bash
#
# Clipboard history. Pick an entry, put it back on the clipboard, paste it.

set -euo pipefail

# cliphist emits "<id>\t<preview>" with the preview capped near 100 characters.
# The window has to be wide enough to show all of it: rofi matches the whole
# row but elides what will not fit, so a narrower menu ranks entries by words
# it never draws — you would land on a row with no visible match and paste
# something else entirely. Only the preview is displayed; the id rides along in
# the hidden first column and is what cliphist decodes.
selection="$(cliphist list |
    rofi -dmenu -i -p 'Clipboard' -display-columns 2 \
        -theme-str 'window { width: 980px; } listview { lines: 12; }')" || exit 0

id="${selection%%$'\t'*}"
[[ -n "$id" && "$id" != "$selection" ]] || exit 0

temporary="$(mktemp --tmpdir dotfiles-clipboard.XXXXXX)"
trap 'rm -f -- "$temporary"' EXIT
cliphist decode "$id" >"$temporary"
[[ -s "$temporary" ]] || exit 0

mime="$(file -b --mime-type "$temporary")"
if [[ "$mime" == image/* ]]; then wl-copy --type "$mime" <"$temporary"; else wl-copy <"$temporary"; fi

sleep 0.15
active_class="$(hyprctl activewindow -j | jq -r '.class // ""' 2>/dev/null || true)"
if [[ "$mime" == image/* && "$active_class" =~ ^(kitty|Alacritty|foot|org\.wezfurlong\.wezterm|com\.mitchellh\.ghostty)$ ]]; then
    notify-send -a Clipboard 'Clipboard' 'Image copied. Paste it into an application that accepts images.'
elif [[ "$active_class" =~ ^(kitty|Alacritty|foot|org\.wezfurlong\.wezterm|com\.mitchellh\.ghostty)$ ]]; then
    wtype -M shift -k Insert -m shift
else
    wtype -M ctrl -k v -m ctrl
fi
