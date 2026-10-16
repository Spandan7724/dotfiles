#!/usr/bin/env bash
set -euo pipefail

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
        # Columns: action, detail, icon, flag; the flag is the last column.
        selection="$({
            printf 'Install packages\tSearch the repositories and pick several\t\U000f03d6\t--install\n'
            printf 'Remove packages\tExplicitly installed packages and their dependencies\t\U000f01b4\t--remove\n'
            printf 'Update the system\tRepositories and AUR, through yay\t\U000f06b0\t--update\n'
            printf 'Remove orphaned packages\tDependencies nothing needs any more\t\U000f00e2\t--orphans\n'
        } | "$HOME/.config/hypr/scripts/menu-select" -no-custom -p 'Packages' \
            -display-columns 1 -detail-column 2 -icon-column 3)" || exit 0
        action="${selection##*$'\t'}"
        [[ -n "$action" && "$action" != "$selection" ]] || exit 0
        exec kitty --class dotfiles-packages --title 'Package manager' -e "$0" "$action" ;;
esac
