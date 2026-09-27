#!/usr/bin/env bash

set -u

hyprctl reload
pkill -SIGUSR2 waybar 2>/dev/null || {
    pkill -x waybar 2>/dev/null || true
    nohup waybar >/dev/null 2>&1 &
}
notify-send -a Dotfiles "Desktop reloaded" "Hyprland and Waybar configuration were refreshed."
