#!/usr/bin/env bash
# Workspace picker (Super+Alt+Tab) on the Quickshell menu (menu-select).
#
#   workspace-menu.sh           go to a workspace; typing a name that is not
#                               listed creates a named workspace and goes there
#   workspace-menu.sh move      send the focused window to a workspace (or a
#                               new named one) and follow it
#   workspace-menu.sh rename    rename the current workspace; an empty name
#                               gives a numbered workspace its number back
#
# Numbered workspaces keep their Super+digit keys after a rename; the name is
# only a label. Hyprland forgets names when a workspace empties and closes.

set -uo pipefail

menu="$HOME/.config/hypr/scripts/menu-select"
mode="${1:-go}"

fail() {
    notify-send -a Workspaces "$1" "${2:-}"
    exit 1
}

# Names go into Lua strings and Waybar markup, so keep them to plain text.
valid_name() {
    [[ "$1" =~ ^[[:alnum:]\ _.-]{1,24}$ && ! "$1" =~ ^[0-9]+$ && "$1" != special* ]]
}

workspaces="$(hyprctl -j workspaces)" || fail "Hyprland is not answering"
clients="$(hyprctl -j clients)" || fail "Hyprland is not answering"
active="$(hyprctl -j activeworkspace | jq -r '.id')"

# One row per workspace, numbered first, then named ones oldest first, as
# tab-separated columns for menu-select:
#   label, detail, icon (the first app's class, or a glyph), section, selector
# A leading "●" marks the current workspace. The selector is matched exactly.
rows() {
    jq -r --argjson c "$clients" --argjson active "$active" '
        map(select(.id > 0 or (.name | startswith("special:") | not)))
        | sort_by(if .id > 0 then [0, .id] else [1, -.id] end)[]
        | . as $ws
        | ([$c[] | select(.workspace.id == $ws.id) | .class | select(. != "")] | unique) as $apps
        | (.id > 0 and .name != (.id | tostring) and .name != "") as $renamed
        | (if .id < 0 or $renamed then .name else "Workspace \(.id)" end) as $label
        | ([(if $renamed then "Workspace \(.id)" else empty end),
            (if .windows == 0 then "empty" else "\(.windows) window\(if .windows == 1 then "" else "s" end)" end),
            ($apps[:3] | join(", ") | select(. != ""))] | join(" · ")) as $detail
        | ($apps[0] // (if .id > 0 then "\uf108" else "\uf02b" end)) as $icon
        | (if .id > 0 then "Workspaces" else "Named" end) as $section
        | (if .id > 0 then (.id | tostring) else "name:\(.name)" end) as $selector
        | (if .id == $active then "● " else "" end) as $marker
        | [$marker + $label, $detail, $icon, $section, $selector] | join("\t")
    ' <<<"$workspaces"
}

menu_args=(-display-columns 1 -detail-column 2 -icon-column 3 -section-column 4
    -placeholder 'Search, or type a name to create')

# Turns a menu answer into a workspace selector: a listed row gives its last
# column, typed text becomes a named workspace.
selector_from() {
    local selection="$1" name
    if [[ "$selection" == *$'\t'* ]]; then
        printf '%s\n' "${selection##*$'\t'}"
        return
    fi
    name="$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"$selection")"
    [[ -n "$name" ]] || return 1
    valid_name "$name" || fail "Invalid workspace name" "Use up to 24 letters, digits, spaces, dots, dashes, or underscores."
    printf 'name:%s\n' "$name"
}

lua_target() {
    if [[ "$1" =~ ^[0-9]+$ ]]; then printf '%s' "$1"; else printf '"%s"' "$1"; fi
}

case "$mode" in
go)
    selection="$({
        rows
        printf 'Move window to…\tSend the focused window to a workspace\t\tActions\taction:move\n'
        printf 'Rename this workspace\tGive it a name, or clear one\t\tActions\taction:rename\n'
    } | "$menu" -p Workspaces "${menu_args[@]}")" || exit 0

    case "$selection" in
    *$'\t'action:move) exec "$0" move ;;
    *$'\t'action:rename) exec "$0" rename ;;
    esac
    target="$(selector_from "$selection")" || exit 0
    hyprctl dispatch "hl.dsp.focus({ workspace = $(lua_target "$target") })" >/dev/null
    ;;

move)
    [[ "$(hyprctl -j activewindow | jq -r '.address // empty')" ]] || fail "No window to move"
    selection="$(rows | "$menu" -p 'Move window to' "${menu_args[@]}")" || exit 0
    target="$(selector_from "$selection")" || exit 0
    hyprctl dispatch "hl.dsp.window.move({ workspace = $(lua_target "$target"), follow = true })" >/dev/null
    ;;

rename)
    current="$(hyprctl -j activeworkspace | jq -r '.name')"
    filter="$current"
    [[ "$active" -gt 0 && "$current" == "$active" ]] && filter=""
    if ((active > 0)); then
        hint="Empty gives it back its number"
    else
        hint="New name"
    fi
    name="$(printf '' | "$menu" -p "Rename workspace $([[ $active -gt 0 ]] && printf '%s' "$active" || printf '%s' "$current")" \
        -placeholder "$hint" -filter "$filter")" || exit 0
    name="$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"$name")"

    if [[ -z "$name" ]]; then
        ((active > 0)) || exit 0
        name="$active"
    elif ! valid_name "$name"; then
        fail "Invalid workspace name" "Use up to 24 letters, digits, spaces, dots, dashes, or underscores."
    elif jq -e --arg n "$name" --argjson a "$active" 'any(.[]; .name == $n and .id != $a)' <<<"$workspaces" >/dev/null; then
        fail "Name already in use" "Another workspace is already called \"$name\"."
    fi
    hyprctl dispatch "hl.dsp.workspace.rename({ workspace = $active, name = \"$name\" })" >/dev/null
    ;;

*)
    printf 'Usage: %s [go|move|rename]\n' "${0##*/}" >&2
    exit 2
    ;;
esac
