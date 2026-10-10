#!/usr/bin/env bash
# Start the default coding agent (Claude Code, Codex, OpenCode, or Amp) in a
# terminal. A small picker asks for the directory first: search the list of
# recent folders and Git repositories, type any path, or press Enter straight
# away to start in the home directory. Default agent: Super+Ctrl+D > Coding agent.

set -euo pipefail

scripts="$HOME/.config/hypr/scripts"
state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/defaults"
recent_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-agent-dirs"

# Stored default first, otherwise the first installed agent.
agent=""
[[ -r "$state_dir/agent" ]] && agent="$(<"$state_dir/agent")"
if [[ -z "$agent" ]] || ! command -v "$agent" >/dev/null 2>&1; then
    agent=""
    for candidate in claude codex opencode amp; do
        command -v "$candidate" >/dev/null 2>&1 && { agent="$candidate"; break; }
    done
fi
if [[ -z "$agent" ]]; then
    notify-send -a Agent "No coding agent installed" "Install Claude Code, Codex, OpenCode, or Amp."
    exit 1
fi

case "$agent" in
    claude) label="Claude Code" ;;
    codex) label="Codex" ;;
    opencode) label="OpenCode" ;;
    amp) label="Amp" ;;
    *) label="$agent" ;;
esac

# Home first so a bare Enter starts there, then recently used folders, then
# Git repositories and other folders near the top of the home directory.
# Each line is "kind<TAB>path".
candidates() {
    printf 'home\t%s\n' "$HOME"
    [[ -r "$recent_file" ]] && sed "s|^~|$HOME|; s|^|recent\t|" -- "$recent_file"
    if command -v fd >/dev/null 2>&1; then
        fd --hidden --no-ignore-vcs --type d --max-depth 5 --prune '^\.git$' "$HOME" \
            --exclude .cache --exclude .local --exclude node_modules 2>/dev/null |
            sed 's|/\.git/\?$||' | grep -v '/\.' | sed 's|^|git\t|'
        fd --type d --max-depth 3 . "$HOME" --exclude node_modules 2>/dev/null |
            sed 's|/$||; s|^|dir\t|'
    else
        find "$HOME" -maxdepth 3 -type d -not -path '*/.*' 2>/dev/null | sed 's|^|dir\t|'
    fi
}

# Rows show a glyph and the ~-relative path; the hidden second column is the
# path that gets used. Typing something that matches no row returns the text.
rows() {
    candidates | awk -F '\t' -v home="$HOME" '
        {
            path = $2
            if (path == home) shown = "~"
            else if (index(path, home "/") == 1) shown = "~" substr(path, length(home) + 1)
            else shown = path
            if (seen[shown]++) next
            icon = $1 == "home" ? "󰋜" : $1 == "recent" ? "󰋚" : $1 == "git" ? "󰊢" : "󰉋"
            label = $1 == "home" ? shown "   home folder" : shown
            print icon "  " label "\t" shown
        }'
}

choice="$(rows | "$scripts/menu-select" -p "󱐋  $label" -display-columns 1 -width 600 \
    -placeholder "Pick a folder or type a path")" || exit 0
[[ "$choice" == *$'\t'* ]] && choice="${choice#*$'\t'}"

dir="${choice:-~}"
dir="${dir/#\~/$HOME}"
if [[ ! -d "$dir" ]]; then
    notify-send -a Agent "Folder not found" "$dir"
    exit 1
fi
dir="$(realpath -- "$dir")"

# Remember the last ten folders (home is always listed anyway).
if [[ "$dir" != "$HOME" ]]; then
    mkdir -p "$(dirname "$recent_file")"
    { printf '%s\n' "${dir/#$HOME/\~}"; [[ -r "$recent_file" ]] && grep -Fxv -- "${dir/#$HOME/\~}" "$recent_file"; } |
        head -n 10 >"$recent_file.tmp" || true
    mv -f -- "$recent_file.tmp" "$recent_file"
fi

# The agent runs inside the user's shell, so the terminal stays open in that
# folder after the agent exits.
# The -c string is plain enough for bash, zsh, and fish alike.
shell="${SHELL:-/bin/bash}"
cd -- "$dir"
exec "$scripts/default-launcher.sh" terminal -e "$shell" -c "$agent; exec $shell"
