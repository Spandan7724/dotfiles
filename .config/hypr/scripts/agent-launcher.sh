#!/usr/bin/env bash
# Start the default coding agent (Claude Code, Codex, OpenCode, or Amp) in a
# terminal. A small picker asks for the directory first: search the list of
# recent folders and Git repositories, type any path, or press Enter straight
# away to start in the home directory. Default agent: Super+Ctrl+D > Coding agent.
#
#   agent-launcher.sh --choose   pick any installed agent first, then the folder

set -euo pipefail

scripts="$HOME/.config/hypr/scripts"
state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/defaults"
recent_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-agent-dirs"

# Known coding agents as "command<TAB>label", in fallback order.
known_agents=$'claude\tClaude Code\ncodex\tCodex\nopencode\tOpenCode\namp\tAmp\ngemini\tGemini CLI\nqwen\tQwen Code\ncrush\tCrush\naider\tAider\ngoose\tGoose\ncursor-agent\tCursor Agent\ncopilot\tGitHub Copilot CLI\ndroid\tFactory Droid\nauggie\tAuggie\nkiro-cli\tKiro\nkimi\tKimi CLI\ngrok\tGrok CLI\nmu\tMu'

installed_agents() {
    while IFS=$'\t' read -r cmd name; do
        command -v "$cmd" >/dev/null 2>&1 && printf '%s\t%s\n' "$cmd" "$name"
    done <<<"$known_agents"
}

# Stored default first, otherwise the first installed agent.
default=""
[[ -r "$state_dir/agent" ]] && default="$(<"$state_dir/agent")"
if [[ -z "$default" ]] || ! command -v "$default" >/dev/null 2>&1; then
    default="$(installed_agents | head -n 1 | cut -f 1)"
fi
if [[ -z "$default" ]]; then
    notify-send -a Agent "No coding agent installed" "Install Claude Code, Codex, OpenCode, Amp, or another CLI agent."
    exit 1
fi

agent="$default"
if [[ "${1:-}" == "--choose" ]]; then
    # The default agent is listed first so a bare Enter picks it, and marked.
    # Rows are "name, command, icon, command"; the last column is used.
    choice="$(installed_agents | awk -F '\t' -v def="$default" -v icon="$(printf '\U000f140b')" '
            $1 == def { first = "● " $2 "\t" $1 "\t" icon "\t" $1; next }
            { rest = rest $2 "\t" $1 "\t" icon "\t" $1 "\n" }
            END { if (first != "") print first; printf "%s", rest }' |
        "$scripts/menu-select" -no-custom -p "Coding agent" -width 600 -placeholder "Pick an agent" \
            -display-columns 1 -detail-column 2 -icon-column 3)" || exit 0
    agent="${choice##*$'\t'}"
    [[ -n "$agent" ]] || exit 0
fi

label="$(awk -F '\t' -v cmd="$agent" '$1 == cmd { print $2 }' <<<"$known_agents")"
label="${label:-$agent}"

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

# Rows are "path, kind, icon, section, path": the ~-relative path, what kind
# of folder it is, a glyph, and its group. The last column is the path that
# gets used. Typing something that matches no row returns the text.
rows() {
    candidates | awk -F '\t' -v home="$HOME" \
        -v home_icon="$(printf '\U000f02dc')" -v recent_icon="$(printf '\U000f02da')" \
        -v git_icon="$(printf '\U000f02a2')" -v dir_icon="$(printf '\U000f024b')" '
        {
            path = $2
            if (path == home) shown = "~"
            else if (index(path, home "/") == 1) shown = "~" substr(path, length(home) + 1)
            else shown = path
            if (seen[shown]++) next
            if ($1 == "home") { icon = home_icon; kind = "Home folder"; section = "Recent" }
            else if ($1 == "recent") { icon = recent_icon; kind = "Recently used"; section = "Recent" }
            else if ($1 == "git") { icon = git_icon; kind = "Git repository"; section = "Repositories" }
            else { icon = dir_icon; kind = "Folder"; section = "Folders" }
            print shown "\t" kind "\t" icon "\t" section "\t" shown
        }'
}

choice="$(rows | "$scripts/menu-select" -p "$(printf '\U000f140b')  $label" -width 600 -placeholder "Pick a folder or type a path" \
    -display-columns 1 -detail-column 2 -icon-column 3 -section-column 4)" || exit 0
[[ "$choice" == *$'\t'* ]] && choice="${choice##*$'\t'}"

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
