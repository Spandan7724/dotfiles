#!/usr/bin/env bash
# Hand the current theme's GTK, Qt, fish, and cava colours to running
# applications. apply.sh runs this after every theme change, and wallpaper.sh
# after a new wallpaper regenerates a wallpaper theme. Every step is best effort.

set -u

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
current="$config_root/themes/current"

# Qt apps read qt6ct's settings when they start.
if [[ -f "$current/qt6ct.conf" ]]; then
    mkdir -p "$config_root/qt6ct"
    cp -f -- "$current/qt6ct.conf" "$config_root/qt6ct/qt6ct.conf"
fi

# fish keeps its colours in universal variables, which open shells share.
if [[ -f "$current/fish.fish" ]] && command -v fish >/dev/null 2>&1; then
    fish -c "source '$current/fish.fish'" 2>/dev/null || true
fi

# cava reloads its config, and with it the theme, on SIGUSR1.
pkill -USR1 -x cava 2>/dev/null || true

# Vicinae reads themes from its data directory; "dotfiles" is the current one.
if [[ -f "$current/vicinae.toml" ]]; then
    vicinae_themes="${XDG_DATA_HOME:-$HOME/.local/share}/vicinae/themes"
    mkdir -p "$vicinae_themes"
    cp -f -- "$current/vicinae.toml" "$vicinae_themes/dotfiles.toml"
    command -v vicinae >/dev/null 2>&1 && timeout 2 vicinae theme set dotfiles >/dev/null 2>&1
fi
exit 0
