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
set_gtk_setting() {
    local file="$1" key="$2" value="$3"
    mkdir -p "$(dirname "$file")"
    [[ -f "$file" ]] || printf '[Settings]\n' >"$file"
    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >>"$file"
    fi
}

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

if [[ "$mode" == dark ]]; then
    gtk_theme=Adwaita-dark
    icon_theme=Papirus-Dark
    prefer_dark=1
else
    gtk_theme=Adwaita
    icon_theme=Papirus
    prefer_dark=0
fi
for gtk_settings in "$config_root/gtk-3.0/settings.ini" "$config_root/gtk-4.0/settings.ini"; do
    set_gtk_setting "$gtk_settings" gtk-theme-name "$gtk_theme"
    set_gtk_setting "$gtk_settings" gtk-icon-theme-name "$icon_theme"
    set_gtk_setting "$gtk_settings" gtk-application-prefer-dark-theme "$prefer_dark"
done

# Theme selection and wallpaper selection are independent. Reusing the current
# wallpaper only regenerates its palette for the selected light or dark mode.
wallpaper_state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-wallpaper"
if [[ -r "$wallpaper_state" ]]; then
    wallpaper="$(<"$wallpaper_state")"
    [[ -f "$wallpaper" ]] && "$themes_root/wallpaper.sh" "$wallpaper" "$mode"
fi

# Named themes ship a Quickshell palette (wallpaper.sh also restores it after
# Matugen runs, but it only runs when a wallpaper has been chosen).
if [[ -f "$theme_dir/quickshell.json" ]]; then
    cp -f -- "$theme_dir/quickshell.json" "$config_root/quickshell/theme.json"
fi

# Helix and btop look themes up by name; "dotfiles" points at the current one.
mkdir -p "$config_root/helix/themes" "$config_root/btop/themes"
ln -sfn ../../themes/current/helix.toml "$config_root/helix/themes/dotfiles.toml"
ln -sfn ../../themes/current/btop.theme "$config_root/btop/themes/dotfiles.theme"

# The rest reaches running applications. Every step is best effort.

# Hyprland: hyprland.lua loads the theme's border colors on reload.
hyprctl reload >/dev/null 2>&1 || true

# Helix re-reads its config and theme on SIGUSR1.
pkill -USR1 -x helix 2>/dev/null || true

# NvChad compiles its theme into a highlight cache that every Neovim loads at
# startup. Rebuild it headlessly, then have running instances load it.
if command -v nvim >/dev/null 2>&1; then
    nvim --headless -c 'lua require("base46").load_all_highlights()' -c 'qa!' >/dev/null 2>&1 || true
    reload_lua='(function() for _, f in ipairs(vim.fn.readdir(vim.g.base46_cache)) do dofile(vim.g.base46_cache .. f) end end)()'
    for server in "${XDG_RUNTIME_DIR:-/tmp}"/nvim.*; do
        [[ -S "$server" ]] || continue
        timeout 2 nvim --server "$server" --remote-expr "luaeval('$reload_lua')" >/dev/null 2>&1 || true
    done
fi

# Doom Emacs: reload the theme in a running Emacs server.
if command -v emacsclient >/dev/null 2>&1 && timeout 2 emacsclient -a false -e t >/dev/null 2>&1; then
    timeout 5 emacsclient -e '(progn
        (load (expand-file-name "~/.config/themes/current/doom.el") t t)
        (mapc (function disable-theme) custom-enabled-themes)
        (load-theme doom-theme t)
        t)' >/dev/null 2>&1 || true
fi

printf 'Applied theme: %s\n' "$theme"
printf 'Thunar and btop windows that are already open pick the theme up when reopened.\n'
