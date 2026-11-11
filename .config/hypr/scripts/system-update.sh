#!/usr/bin/env bash
# Full system update:
#   free-space check -> keyring first -> pacman -Syu (snap-pac takes the
#   before/after snapshots) -> AUR -> orphans -> package cache -> .pacnew
#   report -> firmware check -> reboot notice.
# The machine is kept awake while it runs and everything is logged to
# /tmp/dotfiles-update.log. Opened by the Waybar updates icon and
# Packages > Update the system.
#
#   system-update.sh [-y]     -y skips the confirmation prompts

set -uo pipefail

readonly LOG=/tmp/dotfiles-update.log
readonly MIN_FREE_GIB=3

if [[ -z "${DOTFILES_UPDATE_LOGGED:-}" ]]; then
    exec env DOTFILES_UPDATE_LOGGED=1 script -qefc "$(printf '%q ' "$0" "$@")" "$LOG"
fi

exec 8>"${XDG_RUNTIME_DIR:-/tmp}/dotfiles-update.lock"
if ! flock -n 8; then
    printf 'Another update is already running.\n'
    exit 1
fi

yes=0
[[ "${1:-}" == -y ]] && yes=1

step() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }
confirm() {
    ((yes)) && return 0
    local reply
    read -rp "$1 [Y/n] " reply
    [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

trap 'printf "\n\033[0;31mThe update stopped with an error. Review the output above (also in %s) and run it again.\033[0m\n" "$LOG"' ERR

# ---- Before ------------------------------------------------------------------

free_kib="$(df --output=avail / | tail -n1)"
if ((free_kib < MIN_FREE_GIB * 1024 * 1024)); then
    printf 'Only %s GiB free on /; at least %s GiB is needed. Clear space first (paccache -rk1, old snapshots).\n' \
        "$((free_kib / 1024 / 1024))" "$MIN_FREE_GIB"
    exit 1
fi

step "Checking for updates"
repo_updates="$(checkupdates 2>/dev/null || true)"
aur_updates="$(yay -Qua 2>/dev/null || true)"
repo_count="$(grep -c . <<<"$repo_updates")"
aur_count="$(grep -c . <<<"$aur_updates")"
note "$repo_count repository and $aur_count AUR updates"
if ((repo_count + aur_count == 0)); then
    note "Nothing to update."
else
    [[ -n "$repo_updates" ]] && printf '%s\n' "$repo_updates" | sed 's/^/      /'
    [[ -n "$aur_updates" ]] && printf '%s\n' "$aur_updates" | sed 's/^/      /'
    confirm "Update now?" || exit 0
fi

sudo -v || exit 1
# Keep sudo's timestamp alive for long AUR builds.
(while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done) &
keepalive=$!

# Keep the machine awake (no idle lock, no suspend) for the rest of the run.
systemd-inhibit --what=idle:sleep --who=system-update --why="Updating the system" \
    --mode=block sleep infinity &
inhibitor=$!
trap 'kill "$keepalive" "$inhibitor" 2>/dev/null' EXIT

running_kernel="$(uname -r)"

# ---- Update ------------------------------------------------------------------

if ((repo_count)); then
    # An outdated keyring makes signature checks fail half way through.
    if grep -q '^archlinux-keyring ' <<<"$repo_updates"; then
        step "Updating the keyring first"
        sudo pacman -Sy --needed --noconfirm archlinux-keyring
    fi

    step "Updating repository packages (snap-pac snapshots before and after)"
    if ((yes)); then sudo pacman -Syu --noconfirm; else sudo pacman -Syu; fi
fi

if ((aur_count)); then
    step "Updating AUR packages"
    if ((yes)); then yay -Sua --noconfirm; else yay -Sua; fi
fi

# ---- Clean up ----------------------------------------------------------------

mapfile -t orphans < <(pacman -Qdtq 2>/dev/null || true)
if ((${#orphans[@]})); then
    step "Orphaned packages: ${orphans[*]}"
    confirm "Remove them?" && sudo pacman -Rns --noconfirm "${orphans[@]}"
fi

step "Trimming the package cache (keeping two versions)"
sudo paccache -rk2 -q || true
sudo paccache -ruk0 -q || true

pacnew="$(pacdiff -o 2>/dev/null || true)"
if [[ -n "$pacnew" ]]; then
    step "Config files with a .pacnew/.pacsave to merge (sudo DIFFPROG=nvim -d pacdiff)"
    printf '%s\n' "$pacnew" | sed 's/^/      /'
fi

if command -v fwupdmgr >/dev/null 2>&1; then
    step "Checking for firmware updates"
    fwupdmgr refresh >/dev/null 2>&1 || true
    fwupdmgr get-updates 2>/dev/null || note "No firmware updates."
fi

# ---- After -------------------------------------------------------------------

pkill -RTMIN+10 -x waybar 2>/dev/null || true

if [[ ! -d "/usr/lib/modules/$running_kernel" ]]; then
    step "The kernel was updated: reboot to use it"
    notify-send --app-name=system-update --urgency=critical --icon=system-reboot \
        "Reboot needed" "The kernel was updated. Reboot to load it." 2>/dev/null || true
else
    notify-send --app-name=system-update --icon=system-software-update \
        "System updated" "$repo_count repository and $aur_count AUR packages." 2>/dev/null || true
fi

printf '\n\033[1;32mDone.\033[0m Log: %s\n' "$LOG"
