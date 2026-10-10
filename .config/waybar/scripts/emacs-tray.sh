#!/usr/bin/env bash
# Tray entry for the Emacs server (custom/emacs in Waybar's tray drawer). The
# server keeps running after its last window closes and has no tray icon of
# its own, so this shows one while it runs.
#
# Emacs signals Waybar when it starts and stops (hooks in doom/config.el), so
# the status check runs on those events, plus once a minute in case Emacs
# crashed. It never talks to Emacs itself, so it can never stall it.
#
#   emacs-tray.sh status   JSON for Waybar; empty text hides the icon
#   emacs-tray.sh open     a new Emacs window
#   emacs-tray.sh menu     open a window, or stop the server

set -uo pipefail

socket="${XDG_RUNTIME_DIR:-/run/user/$UID}/emacs/server"

running() {
    [[ -S "$socket" ]] && pgrep -x emacs >/dev/null
}

# Files with unsaved changes, so stopping never loses work silently.
unsaved() {
    emacsclient -a false -e \
        '(length (seq-filter (lambda (b) (and (buffer-file-name b) (buffer-modified-p b))) (buffer-list)))' \
        2>/dev/null || echo 0
}

case "${1:-status}" in
    status)
        if running; then
            # U+E632 is the Emacs logo in Nerd Fonts.
            printf '{"text":"\ue632","tooltip":"Emacs is running in the background\\n\\nClick: new window  •  Right-click: menu","class":"running"}\n'
        else
            printf '{"text":""}\n'
        fi
        ;;
    open)
        exec emacsclient -c -n -a ''
        ;;
    menu)
        running || exit 0
        count="$(unsaved)"
        stop_label="Stop Emacs"
        ((count > 0)) && stop_label="Save $count unsaved file(s) and stop Emacs"
        choice="$(printf '󰏌  New window\topen\n󰓛  %s\tstop\n' "$stop_label" |
            "$HOME/.config/hypr/scripts/menu-select" -p 'Emacs' -display-columns 1 -no-custom)" || exit 0
        case "${choice#*$'\t'}" in
            open) exec emacsclient -c -n -a '' ;;
            stop) emacsclient -e '(progn (save-some-buffers t) (kill-emacs))' >/dev/null 2>&1 ;;
        esac
        ;;
esac
