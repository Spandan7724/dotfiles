#!/usr/bin/env bash
# Emoji and symbol picker on the Quickshell menu, using rofimoji's data files
# (emoji, arrows, maths). The chosen character is copied to the clipboard.

set -euo pipefail

data="$(python3 -c 'import os, picker; print(os.path.join(os.path.dirname(picker.__file__), "data"))' 2>/dev/null)" || {
    notify-send -a Emoji 'Emoji data not found' 'Install rofimoji, which ships the character lists.'
    exit 1
}

# Lines are "<char> <name> <small>(keywords)</small>"; turn them into
# "char<TAB>name<TAB>keywords" for menu-select.
selection="$(cat "$data"/emojis_*.csv "$data"/arrows.csv "$data"/mathematical_operators.csv 2>/dev/null |
    sed -E 's#^([^ ]+) (.*) <small>\((.*)\)</small>$#\1\t\2\t\3#; t; s#^([^ ]+) (.*)$#\1\t\2\t#' |
    "$HOME/.config/hypr/scripts/menu-select" -p 'Emoji and symbols' -placeholder 'Search by name or keyword…' \
        -icon-column 1 -display-columns 2,3 -no-custom -lines 9)" || exit 0

char="${selection%%$'\t'*}"
[[ -n "$char" ]] || exit 0
printf '%s' "$char" | wl-copy
name="${selection#*$'\t'}"; notify-send -a Emoji "$char copied" "${name%%$'\t'*}" 2>/dev/null || true
