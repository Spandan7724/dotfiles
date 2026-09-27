#!/usr/bin/env bash

set -u

if ! command -v checkupdates >/dev/null; then
    printf '{"text":"","tooltip":"Install pacman-contrib for update checks","class":"unavailable"}\n'
    exit 0
fi

updates="$(checkupdates 2>/dev/null || true)"
count="$(printf '%s\n' "$updates" | sed '/^$/d' | wc -l)"

if ((count == 0)); then
    printf '{"text":"","tooltip":"System is up to date","class":"updated"}\n'
else
    tooltip="$(printf '%s\n' "$updates" | head -n 20 | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')"
    printf '{"text":"󰏔 %s","tooltip":"%s","class":"pending"}\n' "$count" "$tooltip"
fi
