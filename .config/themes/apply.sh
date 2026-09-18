#!/usr/bin/env bash

set -euo pipefail

theme="${1:-}"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
themes_root="$config_root/themes"
theme_dir="$themes_root/$theme"

if [[ -z "$theme" || ! -d "$theme_dir" ]]; then
    printf 'Usage: %s <theme>\nAvailable themes:\n' "$0" >&2
    find "$themes_root" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' | sort >&2
    exit 2
fi

temporary_link="$themes_root/.current.$$"
ln -s "$theme" "$temporary_link"
mv -Tf "$temporary_link" "$themes_root/current"

mode="$(<"$theme_dir/mode")"
if command -v gsettings >/dev/null 2>&1; then
    if [[ "$mode" == "dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark 2>/dev/null || true
    else
        gsettings set org.gnome.desktop.interface color-scheme default 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme Adwaita 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme Papirus 2>/dev/null || true
    fi
fi

wallpaper_name="$(<"$theme_dir/wallpaper")"
wallpaper="$HOME/Pictures/Wallpapers/$wallpaper_name"
if [[ -f "$wallpaper" ]]; then
    "$themes_root/wallpaper.sh" "$wallpaper" "$mode"
else
    printf 'Warning: theme wallpaper is missing: %s\n' "$wallpaper" >&2
fi

pkill -USR1 hx 2>/dev/null || true

printf 'Applied theme: %s\n' "$theme"
printf 'Already-running GTK applications may need to be restarted.\n'
