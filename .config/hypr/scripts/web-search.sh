#!/usr/bin/env bash

set -euo pipefail

query="$(printf '' | rofi -dmenu -p 'Search the web' -theme "$HOME/.config/rofi/input.rasi")"
[[ -n "$query" ]] || exit 0

encoded="$(python - "$query" <<'PY'
import sys
from urllib.parse import quote_plus

print(quote_plus(sys.argv[1]))
PY
)"

xdg-open "https://www.google.com/search?q=$encoded" >/dev/null 2>&1 &
