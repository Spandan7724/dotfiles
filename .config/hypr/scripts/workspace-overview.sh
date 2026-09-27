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

# Keep ten predictable workspace targets in a compact two-row grid. Applying
# these settings after the plugin loads avoids unknown-plugin errors during the
# first config parse of a new session.
hyprctl eval 'hl.config({ plugin = { hyprexpo = {
    columns = 5,
    rows = 2,
    dynamic_grid = 0,
    skip_empty = 0,
    max_workspace = 10,
    gaps_in = 10,
    gaps_out = 30,
    workspace_method = "first 1",
    show_workspace_numbers = 1,
    label_position = "top-left",
    label_show = "always",
    label_font_size = 18,
    label_font_family = "JetBrainsMono Nerd Font",
    label_font_bold = 1,
    label_bg_shape = "rounded",
    label_bg_rounding = 8,
    label_padding = 8,
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
