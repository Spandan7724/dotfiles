#!/usr/bin/env bash
set -euo pipefail
if pgrep -x hyprmod >/dev/null 2>&1; then
    hyprctl dispatch 'hl.dsp.focus({ window = "class:^(hyprmod)$" })' >/dev/null 2>&1 || true
else
    exec hyprmod
fi
