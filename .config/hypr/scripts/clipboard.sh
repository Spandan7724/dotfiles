#!/usr/bin/env bash
#
# Clipboard history. Pick an entry, put it back on the clipboard, paste it.

set -euo pipefail

# cliphist emits "<id>\t<preview>" with the preview capped near 100 characters.
# The menu is wide enough to show all of it, so a search never lands on a row
# whose matching words are cut off. Only the preview is displayed; the id rides
# along in the hidden first column and is what cliphist decodes. A third
# column adds a glyph for the kind of entry: image, link, code, or text.
selection="$(cliphist list | awk -F '\t' \
    -v image="$(printf '\U000f02e9')" -v link="$(printf '\U000f0337')" \
    -v code="$(printf '\U000f0169')" -v text="$(printf '\U000f0219')" '
    {
        preview = substr($0, index($0, "\t") + 1)
        if (preview ~ /^\[\[ binary data /) icon = image
        else if (preview ~ /^[a-z][a-z0-9+.-]*:\/\/[^ ]+$/) icon = link
        else if (preview ~ /[{};]$|^(\$ |#!|import |def |function |const |let )/) icon = code
        else icon = text
        print $0 "\t" icon
    }' |
    "$HOME/.config/hypr/scripts/menu-select" -p 'Clipboard' -placeholder 'Search clipboard history…' \
        -display-columns 2 -icon-column 3 -width 980 -lines 12)" || exit 0

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
