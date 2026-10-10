#!/usr/bin/env bash

set -euo pipefail

query="$(printf '' | "$HOME/.config/hypr/scripts/menu-select" -p 'Web search' -placeholder 'Search in your browser…')"
[[ -n "$query" ]] || exit 0

encoded="$(python - "$query" <<'PY'
import sys
from urllib.parse import quote_plus

print(quote_plus(sys.argv[1]))
PY
)"

xdg-open "https://www.google.com/search?q=$encoded" >/dev/null 2>&1 &
