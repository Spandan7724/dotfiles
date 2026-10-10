#!/usr/bin/env bash
# Opens the virtual machine manager window (~/.config/quickshell/vm-manager),
# or closes it when it is already open, so the same key toggles it.
set -uo pipefail

if qs list -c vm-manager 2>/dev/null | grep -q '^Instance'; then
    exec qs kill -c vm-manager
fi
exec qs -n -d -c vm-manager
