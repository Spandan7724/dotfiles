#!/usr/bin/env bash
# Open the desktop menu (quickshell/panels/Menu.qml), optionally at a submenu:
#   menu.sh              the top level; pressing the key again closes it
#   menu.sh setup        straight into Setup
#   menu.sh --apps       the application launcher

set -euo pipefail

if [[ "${1:-}" == --apps ]]; then
    call=(apps)
else
    call=(menu "${1:-}")
fi

if ! qs -c panels ipc call panels "${call[@]}" >/dev/null 2>&1; then
    qs -d -c panels >/dev/null 2>&1
    for _ in $(seq 30); do
        sleep 0.1
        qs -c panels ipc call panels "${call[@]}" >/dev/null 2>&1 && exit 0
    done
    exit 1
fi
