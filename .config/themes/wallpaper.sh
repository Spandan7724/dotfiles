#!/usr/bin/env bash

set -u

wallpaper="${1:-}"
requested_mode="${2:-}"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
themes_root="$config_root/themes"

if [[ -z "$wallpaper" || ! -f "$wallpaper" ]]; then
    printf 'Wallpaper does not exist: %s\n' "${wallpaper:-<missing>}" >&2
    exit 2
fi

mode="$requested_mode"
if [[ -z "$mode" && -r "$themes_root/current/mode" ]]; then
    mode="$(<"$themes_root/current/mode")"
fi

case "$mode" in
    light | dark) ;;
    *) mode="dark" ;;
esac

state_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-wallpaper"
mkdir -p "$(dirname "$state_file")"
printf '%s\n' "$(realpath -- "$wallpaper")" >"$state_file"

if command -v awww >/dev/null 2>&1; then
    if awww query >/dev/null 2>&1; then
        awww img "$wallpaper" -t random --transition-duration 1 || \
            printf 'Warning: awww could not set %s\n' "$wallpaper" >&2
    else
        printf 'Warning: awww-daemon is not running; colors will still be generated.\n' >&2
    fi
fi

if ! command -v matugen >/dev/null 2>&1; then
    printf 'Warning: matugen is unavailable; keeping the fallback application colors.\n' >&2
    exit 0
fi

if ! matugen image "$wallpaper" -m "$mode"; then
    printf 'Warning: Matugen could not derive colors from %s\n' "$wallpaper" >&2
    exit 0
fi

# Quickshell watches theme.json itself. These applications need an explicit
# reload after Matugen rewrites their generated color fragments. Hyprlock and
# Wlogout read their configuration at launch, so they need no signal here.
pkill -SIGUSR2 waybar 2>/dev/null || true
pkill -SIGUSR1 kitty 2>/dev/null || true
if command -v dunstctl >/dev/null 2>&1; then
    dunstctl reload >/dev/null 2>&1 || true
fi

printf 'Applied %s wallpaper colors from: %s\n' "$mode" "$wallpaper"
