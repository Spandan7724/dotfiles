#!/usr/bin/env bash
# Toggle a pop-up (wifi, bluetooth, display, media) or full-screen overlay
# (session, cheatsheet) from ~/.config/quickshell/panels, starting its daemon
# first if needed.

set -euo pipefail

name="${1:?usage: panel.sh wifi|bluetooth|display|media|session|cheatsheet}"

if ! qs -c panels ipc call panels toggle "$name" >/dev/null 2>&1; then
    qs -d -c panels >/dev/null 2>&1
    for _ in $(seq 20); do
        sleep 0.1
        qs -c panels ipc call panels toggle "$name" >/dev/null 2>&1 && exit 0
    done
    exit 1
fi
