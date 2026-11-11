#!/usr/bin/env bash
# Start or stop recording a region of the screen (Super+Shift+R).
# gpu-screen-recorder encodes on the GPU (VA-API/NVENC), so recording costs
# little CPU and holds 60 fps; wf-recorder is the fallback where it is missing.

set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$runtime_dir/dotfiles-recorder.pid"
directory="$HOME/Videos/Recordings"
mkdir -p "$directory"

if [[ -r "$pid_file" ]]; then
    pid="$(<"$pid_file")"
    # Both recorders finish and close the file on SIGINT.
    if kill -INT "$pid" 2>/dev/null; then
        rm -f "$pid_file"
        notify-send -a Recorder "Recording saved" "$directory"
        exit 0
    fi
    rm -f "$pid_file"
fi

if command -v gpu-screen-recorder >/dev/null; then
    recorder=gpu-screen-recorder
elif command -v wf-recorder >/dev/null; then
    recorder=wf-recorder
else
    notify-send -u critical -a Recorder "Screen recorder unavailable" "Install gpu-screen-recorder or wf-recorder first."
    exit 1
fi

# slurp prints "X,Y WxH" in logical coordinates, which both recorders take.
geometry="$(slurp)" || exit 0
output="$directory/$(date '+%Y-%m-%d_%H-%M-%S').mp4"

if [[ "$recorder" == gpu-screen-recorder ]]; then
    [[ "$geometry" =~ ^(-?[0-9]+),(-?[0-9]+)\ ([0-9]+)x([0-9]+)$ ]] || exit 1
    region="${BASH_REMATCH[3]}x${BASH_REMATCH[4]}+${BASH_REMATCH[1]}+${BASH_REMATCH[2]}"
    gpu-screen-recorder -w "$region" -k auto -f 60 -fm cfr -fallback-cpu-encoding yes \
        -o "$output" >/dev/null 2>&1 &
else
    wf-recorder -g "$geometry" -f "$output" >/dev/null 2>&1 &
fi
printf '%s\n' "$!" >"$pid_file"
notify-send -a Recorder "Recording started" "Press Super+Shift+R to stop."
