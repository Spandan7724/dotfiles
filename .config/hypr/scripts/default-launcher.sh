#!/usr/bin/env bash
set -euo pipefail
kind="${1:-}"; shift || true
state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/defaults"
read_default() { local name="$1" fallback="$2"; if [[ -r "$state_dir/$name" ]]; then cat "$state_dir/$name"; else printf '%s' "$fallback"; fi; }
case "$kind" in
    terminal) exec "$(read_default terminal kitty)" "$@" ;;
    browser) exec "$(read_default browser zen-browser)" "$@" ;;
    file-manager) exec "$(read_default file-manager thunar)" "$@" ;;
    editor) editor="$(read_default editor nvim)"; case "$editor" in nvim|vim|hx|helix) exec "$(read_default terminal kitty)" -e "$editor" "$@" ;; *) exec "$editor" "$@" ;; esac ;;
    notes)
        # doom and nvim start a new Markdown note in ~/notes (created on first
        # save); app:<desktop-id> launches a notes app picked in defaults-menu.sh.
        notes="$(read_default notes doom)"
        mkdir -p "$HOME/notes"
        note="$HOME/notes/$(date '+%Y-%m-%d_%H-%M-%S').md"
        case "$notes" in
            doom) exec emacsclient -c -a '' "$note" ;;
            nvim) exec "$(read_default terminal kitty)" -e nvim "$note" ;;
            app:*) exec gtk-launch "${notes#app:}" ;;
            *) exit 2 ;;
        esac ;;
    *) exit 2 ;;
esac
