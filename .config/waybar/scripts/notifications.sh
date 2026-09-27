#!/usr/bin/env bash

set -u

paused="$(dunstctl is-paused 2>/dev/null || printf false)"
count="$(dunstctl count history 2>/dev/null || printf 0)"

if [[ "$paused" == true ]]; then
    printf '{"text":"󰂛","tooltip":"Do not disturb enabled • %s in history","class":"paused"}\n' "$count"
elif ((count > 0)); then
    printf '{"text":"󰂚 %s","tooltip":"%s notifications in history\\nClick: show last • Middle-click: clear all","class":"unread"}\n' "$count" "$count"
else
    printf '{"text":"󰂜","tooltip":"No notification history","class":"empty"}\n'
fi
