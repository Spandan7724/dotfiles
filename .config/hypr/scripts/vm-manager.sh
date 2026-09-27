#!/usr/bin/env bash
set -euo pipefail
connection='qemu:///system'
menu_theme="$HOME/.config/rofi/menu.rasi"

choose_vm() {
    virsh -c "$connection" list --all --name 2>/dev/null | sed '/^$/d' |
        rofi -dmenu -i -no-custom -p "$1" -theme "$menu_theme"
}

selection="$({
    printf '󰢹  Open Virtual Machine Manager\topen\n'
    printf '󰐕  Create a virtual machine\tcreate\n'
    printf '󰐊  Start or open a virtual machine\tstart\n'
    printf '󰓛  Shut down a virtual machine\tshutdown\n'
    printf '󰜉  Force stop a virtual machine\tdestroy\n'
} | rofi -dmenu -i -no-custom -p 'Virtual machines' -display-columns 1 \
    -theme "$menu_theme" -theme-str 'window { width: 470px; }')" || exit 0

action="${selection#*$'\t'}"
[[ -n "$action" && "$action" != "$selection" ]] || exit 0

case "$action" in
    open) virt-manager --connect "$connection" ;;
    create) virt-manager --connect "$connection" --show-domain-creator ;;
    start)
        vm="$(choose_vm 'Start or open VM')" || exit 0
        [[ -n "$vm" ]] || exit 0
        virsh -c "$connection" domstate "$vm" | grep -qi running || virsh -c "$connection" start "$vm"
        virt-manager --connect "$connection" --show-domain-console "$vm" ;;
    shutdown)
        vm="$(choose_vm 'Shut down VM')" || exit 0
        [[ -n "$vm" ]] && virsh -c "$connection" shutdown "$vm" ;;
    destroy)
        vm="$(choose_vm 'Force stop VM')" || exit 0
        [[ -n "$vm" ]] && virsh -c "$connection" destroy "$vm" ;;
esac
