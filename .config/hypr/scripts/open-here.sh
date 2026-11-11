#!/usr/bin/env bash
# Open the default terminal or file manager in the folder the focused
# terminal is in (Super+Alt+T, Super+Alt+E). With no terminal focused, it
# opens in the home folder.
#
#   open-here.sh terminal | file-manager

set -uo pipefail

kind="${1:-terminal}"
case "$kind" in
    terminal | file-manager) ;;
    *) printf 'Usage: %s terminal|file-manager\n' "$0" >&2; exit 2 ;;
esac

# A child of the terminal that is an interactive shell: it leads its own
# session on a tty (a shell some other app spawned does not) and is a login
# shell listed in /etc/shells.
is_terminal_shell() {
    local pid="$1" stat session tty_nr shell
    read -r stat 2>/dev/null <"/proc/$pid/stat" || return 1
    read -r _ _ _ session tty_nr _ <<<"${stat##*) }"
    ((session == pid && tty_nr != 0)) || return 1
    shell="$(readlink -f "/proc/$pid/exe" 2>/dev/null)"
    grep -Fqs "/${shell##*/}" /etc/shells
}

# The working directory of the shell in the focused window. Ghostty (and
# kitty with single-instance) run every window from one process, so the
# window's shell is told apart by its title: an idle fish titles the window
# with prompt_pwd (~/c/dotfiles). Without a match, the newest shell is used.
focused_cwd() {
    local window window_pid title children_file child newest="" cwd short
    window="$(hyprctl -j activewindow 2>/dev/null)" || return 1
    window_pid="$(jq -r '.pid // empty' <<<"$window")"
    title="$(jq -r '.title // empty' <<<"$window")"
    [[ "$window_pid" =~ ^[0-9]+$ ]] || return 1

    local -a shells=()
    for children_file in /proc/"$window_pid"/task/*/children; do
        [[ -r "$children_file" ]] || continue
        read -ra children <"$children_file" || true
        for child in "${children[@]}"; do
            is_terminal_shell "$child" || continue
            shells+=("$child")
            ((child > ${newest:-0})) && newest="$child"
        done
    done
    [[ -n "$newest" ]] || return 1

    if ((${#shells[@]} > 1)) && [[ -n "$title" ]] && command -v fish >/dev/null; then
        local -a matches=()
        for child in "${shells[@]}"; do
            cwd="$(readlink -f "/proc/$child/cwd" 2>/dev/null)" || continue
            short="$(cd -- "$cwd" 2>/dev/null && fish --no-config -c prompt_pwd 2>/dev/null)"
            # Programs such as coding agents end the title with the full path.
            if [[ "$short" == "$title" || "$title" == *" ${cwd/#"$HOME"/"~"}" ]]; then
                matches+=("$cwd")
            fi
        done
        # Several windows in the same folder all give the right answer.
        if ((${#matches[@]})); then
            printf '%s\n' "${matches[0]}"
            return 0
        fi
    fi
    readlink -f "/proc/$newest/cwd" 2>/dev/null
}

dir="$(focused_cwd)"
[[ -d "$dir" ]] || dir="$HOME"

launcher="$HOME/.config/hypr/scripts/default-launcher.sh"
cd -- "$dir" || exit 1
if [[ "$kind" == file-manager ]]; then
    exec "$launcher" file-manager "$dir"
fi

# Most terminals start in the directory they are launched from. Ghostty and
# kitty can hand the window to an already running instance, so they get the
# folder explicitly.
terminal="$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/defaults/terminal" 2>/dev/null || echo kitty)"
case "${terminal##*/}" in
    ghostty) exec "$launcher" terminal --working-directory="$dir" ;;
    kitty) exec "$launcher" terminal --directory "$dir" ;;
    alacritty) exec "$launcher" terminal --working-directory "$dir" ;;
    foot) exec "$launcher" terminal --working-directory="$dir" ;;
    *) exec "$launcher" terminal ;;
esac
