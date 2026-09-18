#!/usr/bin/env bash

# Refine the installer-generated monitor rule once Hyprland can report the
# actual connector and its refresh rates. User-maintained machine.lua files are
# never overwritten.

set -uo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
machine_file="$config_dir/machine.lua"
generated_marker="-- Generated automatically by the dotfiles hardware detector."

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

if [[ -f "$machine_file" ]] && ! grep -Fqx -- "$generated_marker" "$machine_file"; then
    exit 0
fi

monitor_json="$(hyprctl -j monitors all 2>/dev/null)" || exit 0

output="$({
    jq -r '.[] | select(.name | test("^(eDP|LVDS|DSI)-")) | .name' <<<"$monitor_json"
    jq -r '.[] | select(.focused == true) | .name' <<<"$monitor_json"
    jq -r '.[0].name // empty' <<<"$monitor_json"
} | awk 'NF { print; exit }')"

[[ "$output" =~ ^[A-Za-z0-9._:-]+$ ]] || exit 0

best_mode=""
best_width=0
best_height=0
best_pixels=0
best_refresh_milli=0

while IFS= read -r candidate; do
    candidate="${candidate%Hz}"
    if [[ "$candidate" =~ ^([0-9]+)x([0-9]+)@([0-9.]+)$ ]]; then
        width="${BASH_REMATCH[1]}"
        height="${BASH_REMATCH[2]}"
        refresh="${BASH_REMATCH[3]}"
        pixels=$((width * height))
        refresh_milli="$(awk -v value="$refresh" 'BEGIN { printf "%.0f", value * 1000 }')"

        if ((pixels > best_pixels)) \
            || ((pixels == best_pixels && refresh_milli > best_refresh_milli)); then
            best_mode="$candidate"
            best_width="$width"
            best_height="$height"
            best_pixels="$pixels"
            best_refresh_milli="$refresh_milli"
        fi
    fi
done < <(
    jq -r --arg output "$output" \
        '.[] | select(.name == $output) | .availableModes[]?' <<<"$monitor_json"
)

if [[ -z "$best_mode" ]]; then
    read -r best_width best_height refresh < <(
        jq -r --arg output "$output" '
            .[] | select(.name == $output)
            | [.width, .height, .refreshRate] | @tsv
        ' <<<"$monitor_json"
    )

    [[ "$best_width" =~ ^[0-9]+$ && "$best_height" =~ ^[0-9]+$ ]] || exit 0
    best_mode="${best_width}x${best_height}@${refresh}"
fi

scale=1
if ((best_width >= 3000 && best_height >= 1800)); then
    scale=2
elif ((best_width >= 2500 || best_height >= 1400)); then
    scale=1.5
fi

mkdir -p "$config_dir"
temporary_file="$(mktemp "$config_dir/.machine.lua.XXXXXX")" || exit 0
trap 'rm -f -- "$temporary_file"' EXIT

{
    printf '%s\n' "$generated_marker"
    printf '%s\n' 'return {'
    printf '%s\n' '    monitors = {'
    printf '%s\n' '        {'
    printf '            output = "%s",\n' "$output"
    printf '            mode = "%s",\n' "$best_mode"
    printf '%s\n' '            position = "0x0",'
    printf '            scale = %s,\n' "$scale"
    printf '%s\n' '        },'
    printf '%s\n' '    },'
    printf '%s\n' '}'
} >"$temporary_file"

if [[ -f "$machine_file" ]] && cmp -s -- "$temporary_file" "$machine_file"; then
    exit 0
fi

mv -f -- "$temporary_file" "$machine_file"
trap - EXIT
hyprctl reload >/dev/null 2>&1 || true
