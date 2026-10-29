#!/usr/bin/env bash
# Display scale and desktop text size, used by the Display panel
# (~/.config/quickshell/panels) and usable directly:
#
#   display.sh status            JSON: focused monitor, scale, text size, brightness
#   display.sh scale <value>     set the focused monitor's scale (1-3)
#   display.sh text <percent>    set text size (80-150%): GTK apps, Kitty, Ghostty
#   display.sh brightness <pct>  set the backlight
#
# Scale is persisted to hypr/machine.lua when the monitor is listed there, so it
# survives reloads and reboots. Adapted from Omarchy's
# omarchy-hyprland-monitor-scaling and omarchy-display-text-size.

set -euo pipefail

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
state_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-text-size"
kitty_size_file="$config_root/kitty/text-size.conf"
ghostty_size_file="$config_root/ghostty/text-size.ghostty"
machine_lua="$config_root/hypr/machine.lua"
kitty_base_pt=10

focused_monitor() {
    hyprctl -j monitors | jq -ec '.[] | select(.focused)'
}

text_percent() {
    local value=100
    [[ -r "$state_file" ]] && value="$(<"$state_file")"
    [[ "$value" =~ ^[0-9]+$ ]] || value=100
    printf '%s' "$value"
}

# Hyprland only accepts scales where the mode divides into whole logical pixels
# (in 1/120 steps). Round the request up to the nearest value it accepts.
clean_scale() {
    awk -v scale="$1" -v width="$2" -v height="$3" '
        function gcd(a, b, t) { while (b) { t = a % b; a = b; b = t } return a }
        BEGIN {
            g = gcd(width * 120, height * 120)
            k = int(scale * 120 + 0.5)
            if (k > g) k = g
            while (g % k != 0) k++
            printf "%g\n", k / 120
        }'
}

set_scale() {
    local requested="$1" monitor name width height refresh scale
    awk -v s="$requested" 'BEGIN { exit !(s >= 1 && s <= 3) }' || {
        echo "Scale must be between 1 and 3." >&2
        exit 2
    }

    monitor="$(focused_monitor)"
    name="$(jq -r .name <<<"$monitor")"
    width="$(jq -r .width <<<"$monitor")"
    height="$(jq -r .height <<<"$monitor")"
    refresh="$(jq -r .refreshRate <<<"$monitor")"

    # The name is interpolated into Lua below, so only plain connector names pass.
    [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Refusing unsafe monitor name" >&2; exit 1; }

    scale="$(clean_scale "$requested" "$width" "$height")"
    hyprctl eval "hl.monitor({ output = \"$name\", mode = \"${width}x${height}@${refresh}\", position = \"auto\", scale = $scale })" >/dev/null

    # Persist into this monitor's entry in machine.lua, if it has one.
    if [[ -f "$machine_lua" ]] && grep -q "output = \"$name\"" "$machine_lua"; then
        awk -v name="$name" -v scale="$scale" '
            $0 ~ "output = \"" name "\"" { inside = 1 }
            inside && /^[[:space:]]*scale[[:space:]]*=/ { sub(/=.*/, "= " scale ","); inside = 0 }
            inside && /^[[:space:]]*}/ { inside = 0 }
            { print }
        ' "$machine_lua" >"$machine_lua.tmp" && mv -- "$machine_lua.tmp" "$machine_lua"
    fi
}

set_text() {
    local percent="$1" factor kitty_pt
    [[ "$percent" =~ ^[0-9]+$ ]] && ((percent >= 80 && percent <= 150)) || {
        echo "Text size must be a whole percentage from 80 to 150." >&2
        exit 2
    }

    mkdir -p "$(dirname "$state_file")"
    printf '%s\n' "$percent" >"$state_file"

    factor="$(awk -v p="$percent" 'BEGIN { printf "%.2f", p / 100 }')"
    gsettings set org.gnome.desktop.interface text-scaling-factor "$factor" 2>/dev/null || true

    # Kitty keeps its base size in kitty.conf; this generated override is
    # pulled in by a globinclude at the end of it. Half-point steps.
    kitty_pt="$(awk -v p="$percent" -v b="$kitty_base_pt" 'BEGIN { printf "%.1f", int(b * p / 100 * 2 + 0.5) / 2 }')"
    if ((percent == 100)); then
        rm -f -- "$kitty_size_file" "$ghostty_size_file"
    else
        printf '# Written by hypr/scripts/display.sh; delete to use kitty.conf.\nfont_size %s\n' "$kitty_pt" >"$kitty_size_file"
        # Ghostty shares Kitty's base size (font-size in config.ghostty).
        mkdir -p "$(dirname "$ghostty_size_file")"
        printf '# Written by hypr/scripts/display.sh; delete to use config.ghostty.\nfont-size = %s\n' "$kitty_pt" >"$ghostty_size_file"
    fi
    pkill -USR1 -x kitty 2>/dev/null || true
    pkill -USR2 -x ghostty 2>/dev/null || true
}

case "${1:-status}" in
    status)
        monitor="$(focused_monitor)"
        brightness="$(brightnessctl -e4 -m 2>/dev/null | awk -F, '{ gsub("%", "", $4); print $4; exit }')"
        jq -nc \
            --argjson monitor "$monitor" \
            --argjson text "$(text_percent)" \
            --arg brightness "${brightness:-}" \
            '{
                monitor: $monitor.name,
                description: $monitor.description,
                width: $monitor.width,
                height: $monitor.height,
                scale: $monitor.scale,
                text: $text,
                brightness: (if $brightness == "" then null else ($brightness | tonumber) end)
            }'
        ;;
    scale) set_scale "${2:?scale value required}" ;;
    text) set_text "${2:?text percentage required}" ;;
    brightness)
        value="${2:?brightness percentage required}"
        [[ "$value" =~ ^[0-9]+$ ]] || exit 2
        ((value < 1)) && value=1
        brightnessctl -e4 -n2 set "$value%" >/dev/null
        ;;
    *)
        sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2
        exit 2
        ;;
esac
