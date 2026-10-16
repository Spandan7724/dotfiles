#!/usr/bin/env bash
# Keep the custom workspace buttons (custom/ws1..20, custom/wsnamed1..5,
# custom/ws-special) current.
# Waybar runs this as the hidden custom/ws-watch module, so it lives and dies
# with the bar.
#
# On each burst of Hyprland workspace/window events it asks Hyprland once for
# monitors and workspaces, renders every button in one jq pass into
# $XDG_RUNTIME_DIR/waybar-workspaces/<id>.json, and sends signal 8; each
# button then only reads its own small file (workspace.sh).

set -u

socket="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
cache="${XDG_RUNTIME_DIR}/waybar-workspaces"
mkdir -p "$cache"

render() {
    local monitors workspaces id json
    monitors="$(hyprctl -j monitors 2>/dev/null)" || return
    workspaces="$(hyprctl -j workspaces 2>/dev/null)" || return
    while IFS=$'\t' read -r id json; do
        printf '%s\n' "$json" >"$cache/$id.json.tmp" && mv -f "$cache/$id.json.tmp" "$cache/$id.json"
    done < <(jq -rn --argjson m "$monitors" --argjson w "$workspaces" '
        ([$m[] | select(.focused)][0] // $m[0]) as $f
        | ($f.activeWorkspace.id) as $active
        # A renamed numbered workspace shows its name after the number.
        | (range(1; 21) as $id
            | ([$w[] | select(.id == $id)][0]) as $ws
            | (if $id == 10 then "0" else ($id | tostring) end) as $number
            | (($ws.name // "") | if . != "" and . != ($id | tostring) then . else null end) as $name
            | (if $name then "\($number) \($name)" else $number end) as $label
            | (if $name then "Workspace \($id): \($name)" else "Workspace \($id)" end) as $tooltip
            | (if $id == $active then {text: $label, class: ["ws", "active"], tooltip: $tooltip}
               elif $ws != null then {text: $label, class: (if $ws.windows == 0 then ["ws", "empty"] else ["ws"] end), tooltip: $tooltip}
               else {text: ""} end)
            | "\($id)\t\(tojson)"),
          # Named workspaces have negative ids (special ones are named
          # "special:..."); they fill the named1..named5 slots oldest first.
          ([$w[] | select(.id < 0 and (.name | startswith("special:") | not))] | sort_by(-.id)) as $named
          | (range(1; 6) as $slot
            | ($named[$slot - 1]) as $ws
            | (if $ws == null then {text: ""}
               else {text: $ws.name, alt: $ws.name, tooltip: "Named workspace: \($ws.name)",
                     class: (if $ws.id == $active then ["ws", "named", "active"]
                             elif $ws.windows == 0 then ["ws", "named", "empty"] else ["ws", "named"] end)} end)
            | "named\($slot)\t\(tojson)"),
          (($f.specialWorkspace.name // "") as $s
            | (if $s != "" then {text: "󱄅", class: ["ws", "special"], tooltip: ($s | sub("^special:"; ""))}
               else {text: ""} end)
            | "special\t\(tojson)")')
    pkill -RTMIN+8 -x waybar 2>/dev/null || true
}

render

socat -U - "UNIX-CONNECT:$socket" | while read -r line; do
    case "$line" in
        workspace\>\>* | workspacev2\>\>* | createworkspace* | destroyworkspace* | \
        focusedmon* | activespecial* | moveworkspace* | renameworkspace* | \
        openwindow\>\>* | closewindow\>\>* | movewindow\>\>* | movewindowv2\>\>*)
            # One switch arrives as several events; let the burst finish and
            # render once.
            while read -r -t 0.03 _; do :; done
            render
            ;;
    esac
done
