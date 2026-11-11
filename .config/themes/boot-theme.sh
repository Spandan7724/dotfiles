#!/usr/bin/env bash
# Carry the desktop theme to the login screen (SDDM) and boot splash
# (Plymouth). Called at the end of apply.sh and wallpaper.sh; the root half is
# /usr/local/libexec/dotfiles-boot-theme-root (code/dotfiles/system), which
# system/setup-extras.sh installs with a NOPASSWD sudo rule. Without that
# helper this does nothing.
#
#   boot-theme.sh [--force] [--foreground]
#
# By default it runs in the background and skips work when neither the
# palette nor the wallpaper changed since the last sync. A Plymouth colour
# change rebuilds the initramfs, which takes a while.

set -uo pipefail

helper=/usr/local/libexec/dotfiles-boot-theme-root
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
palette="$config_root/quickshell/theme.json"
signature_file="$state_root/dotfiles-boot-theme.signature"
log="$state_root/dotfiles-boot-theme.log"

force=0 foreground=0
for arg in "$@"; do
    case "$arg" in
        --force) force=1 ;;
        --foreground) foreground=1 ;;
    esac
done

[[ -x "$helper" && -r "$palette" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# theme.json holds the resolved palette for named and wallpaper themes alike.
# Colours there may carry an alpha prefix (#aarrggbb); keep the rgb part.
read -r bg fg accent surface muted error on_accent < <(jq -r '
    def rgb: if (. // "") | test("^#[0-9a-fA-F]{8}$") then "#" + .[3:] else . end;
    [ .background, .foreground, .primary, .surfaceVariant, .muted, .error, .onPrimary ]
    | map(rgb) | @tsv' "$palette" 2>/dev/null) || exit 0

wallpaper=""
[[ -r "$state_root/dotfiles-wallpaper" ]] && wallpaper="$(<"$state_root/dotfiles-wallpaper")"
[[ -f "$wallpaper" ]] || wallpaper=""

signature="$bg $fg $accent $surface $muted $error $on_accent $wallpaper"
if ((!force)) && [[ "$(cat "$signature_file" 2>/dev/null)" == "$signature" ]]; then
    exit 0
fi

run() {
    mkdir -p "$state_root"
    if sudo -n "$helper" "$bg" "$fg" "$accent" "$surface" "$muted" "$error" "$on_accent" ${wallpaper:+"$wallpaper"}; then
        printf '%s\n' "$signature" >"$signature_file"
    else
        printf 'boot-theme: the helper failed; see %s\n' "$log" >&2
        return 1
    fi
}

if ((foreground)); then
    run
else
    # One sync at a time; a newer theme change waits for the running rebuild.
    (
        flock 9
        run
    ) 9>"${XDG_RUNTIME_DIR:-/tmp}/dotfiles-boot-theme.lock" >>"$log" 2>&1 &
    disown
fi
