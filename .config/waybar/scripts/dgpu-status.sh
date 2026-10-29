#!/usr/bin/env bash
# Waybar: an icon while any app is using the NVIDIA GPU, with the apps listed
# in the tooltip; empty text (module hidden) otherwise. Holders are found from
# open device files in /proc, which never wakes the GPU. The compositor is
# left out: Hyprland and Xwayland keep the card open all the time.

set -uo pipefail

nodes=(-lname '/dev/nvidia[0-9]*')
for dev in /sys/bus/pci/drivers/nvidia/0000:*; do
    for node in "$dev"/drm/card* "$dev"/drm/renderD*; do
        [[ -e "$node" ]] && nodes+=(-o -lname "/dev/dri/${node##*/}")
    done
done

mapfile -t pids < <(find /proc/[0-9]*/fd -maxdepth 1 \( "${nodes[@]}" \) 2>/dev/null | cut -d/ -f3 | sort -un)

# Window class by pid, so a helper process (a browser's GPU or decoder
# process, a game under Steam) is named after the app whose window it serves.
declare -A window_class
while IFS=$'\t' read -r pid class; do
    window_class[$pid]="$class"
done < <(hyprctl clients -j 2>/dev/null | jq -r '.[] | "\(.pid)\t\(.initialClass // .class)"')

# A window class as the app's name from its desktop file, if one matches.
app_name() {
    local class="$1" dirs=("${XDG_DATA_HOME:-$HOME/.local/share}/applications") data dir file
    IFS=: read -ra data <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for dir in "${data[@]}"; do dirs+=("$dir/applications"); done
    for dir in "${dirs[@]}"; do
        for file in "$dir/$class.desktop" "$dir/${class,,}.desktop"; do
            [[ -f "$file" ]] && break 2
        done
        file="$(grep -lixF "StartupWMClass=$class" "$dir"/*.desktop 2>/dev/null | head -1)"
        [[ -n "$file" ]] && break
    done
    [[ -f "$file" ]] && sed -n '/^\[Desktop Entry\]/,/^\[/{s/^Name=//p}' "$file" | head -1 | grep . || printf '%s\n' "$class"
}

declare -A count=()
for pid in "${pids[@]}"; do
    comm="$(cat "/proc/$pid/comm" 2>/dev/null)" || continue
    case "$comm" in Hyprland | Xwayland | .Hyprland-wrapp*) continue ;; esac

    # Stop at a shell: something run from a terminal is named after the
    # command (the shell's child), not after the terminal.
    name="" p="$pid" below="$comm"
    while [[ -n "$p" && "$p" -gt 1 ]]; do
        if [[ -n "${window_class[$p]:-}" ]]; then
            name="$(app_name "${window_class[$p]}")"
            break
        fi
        c="$(cat "/proc/$p/comm" 2>/dev/null)"
        case "$c" in
            bash | zsh | fish | sh | dash | nu) name="$below"; break ;;
            prime-run | env | nohup | setsid | timeout | gamemoderun | uwsm*) ;;
            *) below="$c" ;;
        esac
        p="$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null)"
    done
    count["${name:-$comm}"]=$((${count["${name:-$comm}"]:-0} + 1))
done

if ((${#count[@]} == 0)); then
    printf '{"text":"","tooltip":"","class":"idle"}\n'
    exit 0
fi

# Something holds the GPU, so it is awake already and nvidia-smi is free.
stats="$(nvidia-smi --query-gpu=utilization.gpu,memory.used,power.draw,temperature.gpu \
    --format=csv,noheader,nounits 2>/dev/null |
    awk -F ', *' 'NR == 1 { printf "%s%% load · %s MiB · %.0f W · %s°C", $1, $2, $3, $4 }')"

tooltip="<b>Running on the NVIDIA GPU</b>"
while IFS= read -r name; do
    n="${count[$name]}"
    shown="${name//&/&amp;}"; shown="${shown//</&lt;}"; shown="${shown//>/&gt;}"
    tooltip+=$'\n'"  󰄾  $shown"
    ((n > 1)) && tooltip+="  <span alpha='60%'>${n} processes</span>"
done < <(printf '%s\n' "${!count[@]}" | sort -f)
[[ -n "$stats" ]] && tooltip+=$'\n\n'"<span alpha='60%'>$stats</span>"

jq -cn --arg tooltip "$tooltip" --arg alt "${#count[@]}" \
    '{text: "󰢮", tooltip: $tooltip, class: "active", alt: $alt}'
