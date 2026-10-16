#!/usr/bin/env bash

set -u

hyprctl reload
# Vicinae's script commands mirror the desktop menu (quickshell/panels/menu.json).
"$HOME/.config/vicinae/menu-commands.py" >/dev/null 2>&1 || true
pkill -SIGUSR2 waybar 2>/dev/null || {
    pkill -x waybar 2>/dev/null || true
    nohup waybar >/dev/null 2>&1 &
}
notify-send -a Dotfiles "Desktop reloaded" "Hyprland and Waybar configuration were refreshed."
