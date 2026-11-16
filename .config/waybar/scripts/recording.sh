#!/usr/bin/env bash
# Screen recording indicator, shown only while hypr/scripts/record-toggle.sh
# is recording. One instance per piece of the bar group:
#   recording.sh          the elapsed time
#   recording.sh pause    the pause/resume button (gpu-screen-recorder only)
#   recording.sh stop     the stop button
# Each runs for the life of waybar and prints only when its text changes; the
# loop uses bash builtins alone, so idling costs no process spawns.

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$runtime_dir/dotfiles-recorder.pid"
state_file="$runtime_dir/dotfiles-recorder.state"
mode="${1:-time}"

# A pipe nobody writes to: `read -t` on it is a sleep without forking.
exec {tick}<> <(:)

last=""
while :; do
    out='{"text":"","tooltip":"","class":"idle"}'
    if [[ -r "$pid_file" && -r "$state_file" ]] &&
        read -r pid <"$pid_file" && kill -0 "$pid" 2>/dev/null &&
        read -r recorder start paused_total paused_since <"$state_file"; then
        now=$EPOCHSECONDS
        if ((paused_since > 0)); then
            elapsed=$((paused_since - start - paused_total))
            icon="󰏤" class="paused" status="Recording paused"
        else
            elapsed=$((now - start - paused_total))
            icon="󰻂" class="recording" status="Recording"
        fi
        ((elapsed < 0)) && elapsed=0
        if ((elapsed >= 3600)); then
            printf -v time '%d:%02d:%02d' $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60))
        else
            printf -v time '%02d:%02d' $((elapsed / 60)) $((elapsed % 60))
        fi
        case "$mode" in
            pause)
                if [[ "$recorder" != gpu-screen-recorder ]]; then
                    : # wf-recorder cannot pause; leave the button hidden
                elif [[ "$class" == paused ]]; then
                    out='{"text":"󰐊","tooltip":"Resume recording","class":"paused"}'
                else
                    out='{"text":"󰏤","tooltip":"Pause recording","class":"recording"}'
                fi
                ;;
            stop)
                out='{"text":"󰓛","tooltip":"Stop and save recording","class":"'"$class"'"}'
                ;;
            *)
                out="{\"text\":\"$icon $time\",\"tooltip\":\"$status ($recorder)\",\"class\":\"$class\"}"
                ;;
        esac
    fi
    if [[ "$out" != "$last" ]]; then
        printf '%s\n' "$out"
        last="$out"
    fi
    read -r -t 0.25 -u "$tick" _ || true
done
