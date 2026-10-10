#!/usr/bin/env bash
# Keep the custom workspace buttons (custom/ws1..10, custom/ws-special) current.
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
        | (range(1; 11) as $id
            | ([$w[] | select(.id == $id)][0]) as $ws
            | (if $id == 10 then "0" else ($id | tostring) end) as $label
            | (if $id == $active then {text: $label, class: ["ws", "active"], tooltip: "Workspace \($id)"}
               elif $ws != null then {text: $label, class: (if $ws.windows == 0 then ["ws", "empty"] else ["ws"] end), tooltip: "Workspace \($id)"}
               else {text: ""} end)
            | "\($id)\t\(tojson)"),
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
