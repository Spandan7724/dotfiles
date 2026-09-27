#!/usr/bin/env bash
set -euo pipefail
menu_theme="$HOME/.config/rofi/menu.rasi"

install_packages() {
    mapfile -t packages < <(pacman -Slq | sort -u | fzf --multi --prompt='Install packages > ' \
        --preview='pacman -Sii {} 2>/dev/null' --preview-window='down:65%:wrap' --bind='alt-p:toggle-preview')
    ((${#packages[@]})) && sudo pacman -S --needed "${packages[@]}"
}
remove_packages() {
    mapfile -t packages < <(pacman -Qqet | fzf --multi --prompt='Remove packages > ' \
        --preview='pacman -Qi {} 2>/dev/null' --preview-window='down:65%:wrap' --bind='alt-p:toggle-preview')
    ((${#packages[@]})) && sudo pacman -Rns "${packages[@]}"
}
case "${1:-}" in
    --install) install_packages ;;
    --remove) remove_packages ;;
    --update) yay -Syu ;;
    --orphans)
        mapfile -t packages < <(pacman -Qdtq 2>/dev/null || true)
        if ((${#packages[@]})); then sudo pacman -Rns "${packages[@]}"; else printf 'No orphaned packages.\n'; fi ;;
    *)
        selection="$({
            printf '󰏖  Install packages\t--install\n'
            printf '󰆴  Remove packages\t--remove\n'
            printf '󰚰  Update the system\t--update\n'
            printf '󰃢  Remove orphaned packages\t--orphans\n'
        } | rofi -dmenu -i -no-custom -p 'Packages' -display-columns 1 -theme "$menu_theme")" || exit 0
        action="${selection#*$'\t'}"
        [[ -n "$action" && "$action" != "$selection" ]] || exit 0
        exec kitty --class dotfiles-packages --title 'Package manager' -e "$0" "$action" ;;
esac
