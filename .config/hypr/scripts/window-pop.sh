#!/usr/bin/env bash
# Pop the active tiled window out: float it, size it to a comfortable share of
# the monitor, center it, and pin it so it follows across workspaces. Running
# it again on a popped (pinned) window unpins it and returns it to the tiles.
# Adapted from Omarchy's omarchy-hyprland-window-pop.

set -euo pipefail

active="$(hyprctl -j activewindow)"
address="$(jq -r '.address // empty' <<<"$active")"
[[ -n "$address" ]] || exit 0

window="address:$address"
dispatch() { hyprctl dispatch "$1" >/dev/null; }

if [[ "$(jq -r '.pinned' <<<"$active")" == true ]]; then
    dispatch "hl.dsp.window.pin({ window = \"$window\", action = \"disable\" })"
    dispatch "hl.dsp.window.float({ window = \"$window\", action = \"disable\" })"
    dispatch "hl.dsp.window.tag({ window = \"$window\", tag = \"-pop\" })"
    exit 0
fi

# Monitor size is reported in physical pixels; divide by scale for layout units.
read -r width height < <(hyprctl -j monitors | jq -r '
    .[] | select(.focused) |
    "\((.width / .scale * 0.6) | floor) \((.height / .scale * 0.65) | floor)"')

dispatch "hl.dsp.window.float({ window = \"$window\", action = \"enable\" })"
dispatch "hl.dsp.window.resize({ window = \"$window\", x = $width, y = $height, relative = false })"
dispatch "hl.dsp.window.center({ window = \"$window\" })"
dispatch "hl.dsp.window.pin({ window = \"$window\", action = \"enable\" })"
dispatch "hl.dsp.window.alter_zorder({ window = \"$window\", mode = \"top\" })"
dispatch "hl.dsp.window.tag({ window = \"$window\", tag = \"+pop\" })"
