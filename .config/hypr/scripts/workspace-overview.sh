#!/usr/bin/env bash

set -u

plugin="$HOME/.local/lib/hyprland-plugins/hyprexpo.so"
action="${1:-toggle}"

notify_error() {
    notify-send -a "Workspace overview" "Workspace overview unavailable" "$1"
}

if ! hyprctl plugin list 2>/dev/null | grep -q '^Plugin hyprexpo '; then
    if [[ ! -r "$plugin" ]]; then
        notify_error "Run ~/.config/hypr/scripts/install-hyprexpo.sh to install it."
        exit 1
    fi

    if ! hyprctl plugin load "$plugin" >/dev/null; then
        notify_error "HyprExpo could not be loaded for this Hyprland build."
        exit 1
    fi
fi

# Workspaces 1-10 fill a five-by-two grid. Workspaces 11-20 add two more rows,
# but only while one of them is in use (Hyprland keeps a workspace only while
# it has windows or is shown), so the usual overview has larger tiles.
rows=2
if hyprctl -j workspaces 2>/dev/null | jq -e 'any(.[]; .id >= 11 and .id <= 20)' >/dev/null; then
    rows=4
fi

# The current workspace's number takes the theme's accent colour.
accent="$(sed -nE 's/^accent[[:space:]]*=[[:space:]]*"#([0-9A-Fa-f]{6})".*/\1/p' \
    "${XDG_CONFIG_HOME:-$HOME/.config}/themes/current/colors.toml" 2>/dev/null | head -1)"
accent="${accent:-ffffff}"

# Applying these settings after the plugin loads avoids unknown-plugin errors
# during the first config parse of a new session.
hyprctl eval 'hl.config({ plugin = { hyprexpo = {
    columns = 5,
    rows = '"$rows"',
    dynamic_grid = 0,
    skip_empty = 0,
    max_workspace = '"$((rows * 5))"',
    gaps_in = 10,
    gaps_out = 30,
    workspace_method = "first 1",
    show_workspace_numbers = 0,
    label_enable = 1,
    label_text_mode = "id",
    label_show = "always",
    label_position = "top-left",
    label_offset_x = 16,
    label_offset_y = 16,
    label_font_size = 13,
    label_font_family = "JetBrainsMono Nerd Font",
    label_font_bold = 1,
    label_color_default = "rgba(ffffffcc)",
    label_color_hover = "rgba(ffffffff)",
    label_color_focus = "rgba('"$accent"'ff)",
    label_color_current = "rgba('"$accent"'ff)",
    label_scale_hover = 1.0,
    label_scale_focus = 1.0,
    label_bg_color = "rgba(000000a6)",
    label_bg_shape = "rounded",
    label_bg_rounding = 14,
    label_padding = 10,
    wallpaper_bg = 1,
    drag_drop_enable = 1,
    number_key_mode = "workspace",
} } })' >/dev/null

case "$action" in
    --load | load)
        ;;
    toggle)
        hyprctl eval 'hl.plugin.hyprexpo.expo("toggle all")' >/dev/null
        ;;
    open)
        hyprctl eval 'hl.plugin.hyprexpo.expo("on all")' >/dev/null
        ;;
    close)
        hyprctl eval 'hl.plugin.hyprexpo.expo("off")' >/dev/null
        ;;
    *)
        printf 'Usage: %s [toggle|open|close|--load]\n' "${0##*/}" >&2
        exit 2
        ;;
esac
