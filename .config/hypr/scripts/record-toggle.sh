#!/usr/bin/env bash

set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$runtime_dir/dotfiles-wf-recorder.pid"
directory="$HOME/Videos/Recordings"
mkdir -p "$directory"

if [[ -r "$pid_file" ]]; then
    pid="$(<"$pid_file")"
    if kill -INT "$pid" 2>/dev/null; then
        rm -f "$pid_file"
        notify-send -a Recorder "Recording saved" "$directory"
        exit 0
    fi
    rm -f "$pid_file"
fi

if ! command -v wf-recorder >/dev/null; then
    notify-send -u critical -a Recorder "Screen recorder unavailable" "Install wf-recorder first."
    exit 1
fi

geometry="$(slurp)" || exit 0
output="$directory/$(date '+%Y-%m-%d_%H-%M-%S').mp4"
wf-recorder -g "$geometry" -f "$output" >/dev/null 2>&1 &
printf '%s\n' "$!" >"$pid_file"
notify-send -a Recorder "Recording started" "Press Super+Shift+R to stop."
