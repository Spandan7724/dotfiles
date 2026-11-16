#!/usr/bin/env bash
# Screen recording of a selected region (Super+Shift+R).
#   record-toggle.sh          start, or stop and save if one is running
#   record-toggle.sh stop     stop and save; does nothing when idle
#   record-toggle.sh pause    pause or resume (gpu-screen-recorder only)
# gpu-screen-recorder encodes on the GPU (VA-API/NVENC), so recording costs
# little CPU and holds 60 fps; wf-recorder is the fallback where it is missing.
#
# The waybar module (waybar/scripts/recording.sh) reads the state file to show
# the elapsed time. Its line is "<recorder> <start> <paused-total> <paused-since>",
# in epoch seconds; paused-since is 0 while recording.

set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$runtime_dir/dotfiles-recorder.pid"
state_file="$runtime_dir/dotfiles-recorder.state"
directory="$HOME/Videos/Recordings"
mkdir -p "$directory"

# The saved pid, if it still belongs to a recorder (pids get reused).
running_pid() {
    local pid comm
    [[ -r "$pid_file" ]] || return 1
    pid="$(<"$pid_file")"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    comm="$(cat "/proc/$pid/comm" 2>/dev/null)" || return 1
    [[ "$comm" == gpu-screen-reco || "$comm" == wf-recorder ]] || return 1
    printf '%s\n' "$pid"
}

clear_state() {
    rm -f "$pid_file" "$state_file"
}

stop_recording() {
    local pid
    pid="$(running_pid)" || { clear_state; return 1; }
    # Both recorders finish and close the file on SIGINT, paused or not.
    kill -INT "$pid" 2>/dev/null || true
    clear_state
    # Wait for the file to be finalised before announcing it.
    for _ in {1..50}; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    notify-send -a Recorder "Recording saved" "$directory"
}

pause_recording() {
    local pid recorder start paused_total paused_since now
    pid="$(running_pid)" || { notify-send -a Recorder "Not recording"; exit 1; }
    read -r recorder start paused_total paused_since <"$state_file"
    if [[ "$recorder" != gpu-screen-recorder ]]; then
        notify-send -a Recorder "Pause unavailable" "wf-recorder cannot pause a recording."
        exit 1
    fi
    kill -USR2 "$pid"
    now="$(date +%s)"
    if ((paused_since > 0)); then
        paused_total=$((paused_total + now - paused_since))
        paused_since=0
    else
        paused_since="$now"
    fi
    printf '%s %s %s %s\n' "$recorder" "$start" "$paused_total" "$paused_since" >"$state_file"
}

case "${1:-toggle}" in
    stop)
        stop_recording || true
        exit 0
        ;;
    pause)
        pause_recording
        exit 0
        ;;
    toggle)
        if running_pid >/dev/null; then
            stop_recording
            exit 0
        fi
        clear_state
        ;;
    *)
        echo "usage: ${0##*/} [toggle|stop|pause]" >&2
        exit 2
        ;;
esac

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
printf '%s %s 0 0\n' "$recorder" "$(date +%s)" >"$state_file"
notify-send -a Recorder "Recording started" "Press Super+Shift+R to stop."
