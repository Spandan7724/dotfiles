#!/usr/bin/env bash

set -uo pipefail
helper=/usr/local/libexec/dotfiles-power-profile-root
command -v powerprofilesctl >/dev/null 2>&1 || exit 0
[[ -x "$helper" ]] || exit 0

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/dotfiles-power-profile.lock"
flock -n 9 || exit 0
last=""
while sleep 3; do
    current="$(powerprofilesctl get 2>/dev/null || true)"
    case "$current" in power-saver|balanced|performance) ;; *) continue ;; esac
    if [[ "$current" != "$last" ]]; then
        sudo -n "$helper" "$current" >/dev/null 2>&1 && last="$current"
    fi
done
