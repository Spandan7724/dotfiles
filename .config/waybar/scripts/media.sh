#!/usr/bin/env bash

set -u

if ! status="$(playerctl status 2>/dev/null)"; then
    printf '{"text":"","tooltip":"No active media player","class":"stopped"}\n'
    exit 0
fi

title="$(playerctl metadata --format '{{title}}' 2>/dev/null || true)"
artist="$(playerctl metadata --format '{{artist}}' 2>/dev/null || true)"
album="$(playerctl metadata --format '{{album}}' 2>/dev/null || true)"
player="$(playerctl metadata --format '{{playerName}}' 2>/dev/null || true)"

case "$status" in
    Playing)
        icon="󰐊"
        class="playing"
        ;;
    Paused)
        icon="󰏤"
        class="paused"
        ;;
    *)
        icon="󰓛"
        class="stopped"
        ;;
esac

label="$title"
[[ -n "$label" ]] || label="$artist"
if ((${#label} > 24)); then
    label="${label:0:23}…"
fi

text="$icon"
[[ -z "$label" ]] || text="$text $label"
tooltip="$player"
[[ -z "$title" ]] || tooltip="$tooltip\n$title"
[[ -z "$artist" ]] || tooltip="$tooltip\n$artist"
[[ -z "$album" ]] || tooltip="$tooltip — $album"
tooltip="$tooltip\n\nClick: play/pause  •  Middle: previous  •  Right: next"

jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
