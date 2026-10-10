#!/usr/bin/env bash
# Now-playing text for Waybar's custom/media module. Runs continuously and
# prints a new JSON line whenever any MPRIS player changes track or state, so
# the bar updates immediately instead of polling.

set -u

# A glyph for the player, falling back to a music note.
player_icon() {
    case "${1,,}" in
        spotify*) printf '󰓇' ;;
        firefox* | zen* | librewolf*) printf '󰈹' ;;
        chromium* | chrome* | brave* | vivaldi*) printf '󰖟' ;;
        mpv*) printf '󰐹' ;;
        vlc*) printf '󰕼' ;;
        *) printf '󰎆' ;;
    esac
}

truncate() {
    local text="$1" max="$2"
    if ((${#text} > max)); then
        printf '%s…' "${text:0:max-1}"
    else
        printf '%s' "$text"
    fi
}

emit() {
    local status="$1" player="$2" title="$3" artist="$4" album="$5"

    if [[ -z "$status" || "$status" == Stopped && -z "$title" ]]; then
        printf '{"text":"","class":"stopped"}\n'
        return
    fi

    local class state_icon
    case "$status" in
        Playing) class=playing state_icon="󰐊" ;;
        Paused) class=paused state_icon="󰏤" ;;
        *) class=stopped state_icon="󰓛" ;;
    esac

    local label
    if [[ -n "$title" && -n "$artist" ]]; then
        label="$(truncate "$title" 28)  ·  $(truncate "$artist" 18)"
    else
        label="$(truncate "${title:-$artist}" 40)"
    fi

    local tooltip="$state_icon  ${title:-Unknown track}"
    [[ -z "$artist" ]] || tooltip+=$'\n'"      $artist"
    [[ -z "$album" ]] || tooltip+=$'\n'"      $album"
    tooltip+=$'\n\n'"Playing in $player"$'\n'"Click: player  •  Middle: play/pause  •  Scroll: previous/next"

    jq -cn --arg text "$(player_icon "$player")  $label" --arg tooltip "$tooltip" --arg class "$class" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

# playerctl prints one line per change; an empty line means no player is left.
playerctl --follow metadata \
    --format $'{{status}}\t{{playerName}}\t{{title}}\t{{artist}}\t{{album}}' 2>/dev/null |
while IFS=$'\t' read -r status player title artist album; do
    emit "$status" "$player" "$title" "$artist" "$album"
done
