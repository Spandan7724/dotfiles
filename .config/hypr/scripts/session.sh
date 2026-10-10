#!/usr/bin/env bash
# Backend for the session screen (quickshell/panels/SessionScreen.qml).
#
#   session.sh status          JSON: uptime, battery, which actions this
#                              machine offers, and warnings worth reading first
#   session.sh run <action>    lock | suspend | hibernate | logout | reboot |
#                              windows | firmware | poweroff

set -uo pipefail

scripts="$HOME/.config/hypr/scripts"
windows_helper=/usr/local/libexec/dotfiles-reboot-windows-root

# zram cannot hold a hibernation image, so hibernation is only offered when a
# real swap device exists and the kernel advertises suspend-to-disk.
hibernation_available() {
    grep -q disk /sys/power/state &&
        swapon --show=NAME --noheadings 2>/dev/null | grep -qv '^/dev/zram'
}

firmware_available() {
    compgen -G '/sys/firmware/efi/efivars/OsIndicationsSupported-*' >/dev/null
}

uptime_text() {
    local seconds days hours minutes
    seconds="$(cut -d. -f1 /proc/uptime)"
    days=$((seconds / 86400)) hours=$((seconds % 86400 / 3600)) minutes=$((seconds % 3600 / 60))
    if ((days > 0)); then
        printf '%d d %d h' "$days" "$hours"
    elif ((hours > 0)); then
        printf '%d h %d min' "$hours" "$minutes"
    else
        printf '%d min' "$minutes"
    fi
}

battery_text() {
    local battery capacity state
    for battery in /sys/class/power_supply/BAT*; do
        [[ -r "$battery/capacity" ]] || continue
        capacity="$(<"$battery/capacity")"
        state="$(<"$battery/status")"
        case "$state" in
            Charging) printf '%s%% · charging' "$capacity" ;;
            Full | "Not charging") printf '%s%% · plugged in' "$capacity" ;;
            *) printf '%s%%' "$capacity" ;;
        esac
        return
    done
}

# Things that a restart or shutdown would interrupt.
warnings() {
    if pgrep -x 'pacman|yay|paru|makepkg' >/dev/null; then
        printf 'A package manager is running\n'
    fi
    if find "$HOME/Downloads" -maxdepth 1 \( -name '*.part' -o -name '*.crdownload' -o -name '*.download' \) \
        -mmin -2 -print -quit 2>/dev/null | grep -q .; then
        printf 'A download may still be in progress\n'
    fi
}

status() {
    local hibernate=false windows=false firmware=false
    hibernation_available && hibernate=true
    [[ -x "$windows_helper" ]] && windows=true
    firmware_available && firmware=true
    jq -nc \
        --arg user "${USER:-$(id -un)}" \
        --arg host "$(cat /proc/sys/kernel/hostname)" \
        --arg uptime "$(uptime_text)" \
        --arg battery "$(battery_text)" \
        --argjson hibernate "$hibernate" \
        --argjson windows "$windows" \
        --argjson firmware "$firmware" \
        --arg warnings "$(warnings)" \
        '{user: $user, host: $host, uptime: $uptime, battery: $battery,
          available: {hibernate: $hibernate, windows: $windows, firmware: $firmware},
          warnings: ($warnings | split("\n") | map(select(length > 0)))}'
}

run() {
    case "${1:-}" in
        lock) exec hyprlock ;;
        suspend) exec systemctl suspend ;;
        hibernate)
            systemctl hibernate ||
                notify-send -u critical 'Hibernate failed' 'Check that swap and the resume kernel parameter are configured.'
            ;;
        logout) exec uwsm stop ;;
        reboot) exec systemctl reboot ;;
        windows) exec "$scripts/reboot-windows.sh" ;;
        firmware) exec systemctl reboot --firmware-setup ;;
        poweroff) exec systemctl poweroff ;;
        *) echo "Unknown action: ${1:-}" >&2; exit 2 ;;
    esac
}

case "${1:-status}" in
    status) status ;;
    run) run "${2:-}" ;;
    *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
