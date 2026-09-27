#!/usr/bin/env bash

set -euo pipefail
state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/defaults"
menu_theme="$HOME/.config/rofi/menu.rasi"
mkdir -p "$state_dir"

if [[ "${1:-}" == --set-shell ]]; then
    shell_path="$(command -v "$2")"
    printf 'Changing the login shell to %s\n' "$shell_path"
    chsh -s "$shell_path"
    # chsh only edits /etc/passwd; the session's SHELL was fixed at login and
    # terminals launch whatever it says, so update it in the live session too.
    hyprctl eval "hl.env(\"SHELL\", \"$shell_path\")" >/dev/null
    systemctl --user set-environment SHELL="$shell_path"
    dbus-update-activation-environment SHELL="$shell_path"
    printf '\nNew terminals will now use %s. Press Enter to close.\n' "$shell_path"
    read -r
    exit 0
fi

choose_installed() {
    local prompt="$1"; shift
    local program label choices=""
    while (($# >= 2)); do
        program="$1"; label="$2"; shift 2
        command -v "$program" >/dev/null 2>&1 && choices+="$program\t$label"$'\n'
    done
    printf '%b' "$choices" | sed '/^$/d' | rofi -dmenu -i -no-custom -p "$prompt" -display-columns 2 -theme "$menu_theme"
}

set_mimes() {
    local desktop="$1"; shift
    local mime
    for mime in "$@"; do xdg-mime default "$desktop" "$mime"; done
}

# The rofi menu theme sizes itself to the row count, so no height arithmetic
# is needed here. The hidden second column carries the id that is matched on.
category="$({
    printf '\U000f018d  Terminal\tterminal\n'
    printf '\U000f07b7  Login shell\tshell\n'
    printf '\U000f059f  Web browser\tbrowser\n'
    printf '\U000f0a1e  Code and text editor\teditor\n'
    printf '\U000f024b  File manager\tfile-manager\n'
    printf '\U000f0226  PDF viewer\tpdf\n'
    printf '\U000f02e9  Image viewer\timage\n'
    printf '\U000f0439  Video player\tvideo\n'
} | rofi -dmenu -i -no-custom -p 'Defaults' -display-columns 1 -theme "$menu_theme")" || exit 0
category="${category#*$'\t'}"

case "$category" in
    terminal)
        selection="$(choose_installed 'Default terminal' kitty Kitty foot Foot alacritty Alacritty ghostty Ghostty wezterm WezTerm)"
        program="${selection%%$'\t'*}"; [[ -n "$program" ]] || exit 0
        printf '%s\n' "$program" >"$state_dir/terminal"
        case "$program" in kitty) desktop=kitty.desktop ;; foot) desktop=foot.desktop ;; alacritty) desktop=Alacritty.desktop ;; ghostty) desktop=com.mitchellh.ghostty.desktop ;; wezterm) desktop=org.wezfurlong.wezterm.desktop ;; esac
        printf '%s\n' "$desktop" >"${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list" ;;
    shell)
        selection="$(choose_installed 'Login shell' fish Fish zsh Zsh bash Bash)"
        program="${selection%%$'\t'*}"; [[ -n "$program" ]] || exit 0
        exec kitty --class dotfiles-defaults --title 'Change login shell' -e "$0" --set-shell "$program" ;;
    browser)
        selection="$(choose_installed 'Default browser' zen-browser 'Zen Browser' brave Brave brave-browser Brave firefox Firefox chromium Chromium google-chrome-stable Chrome)"
        program="${selection%%$'\t'*}"; [[ -n "$program" ]] || exit 0
        printf '%s\n' "$program" >"$state_dir/browser"
        case "$program" in zen-browser) desktop=zen.desktop ;; brave|brave-browser) desktop=brave-browser.desktop ;; firefox) desktop=firefox.desktop ;; chromium) desktop=chromium.desktop ;; google-chrome-stable) desktop=google-chrome.desktop ;; esac
        xdg-settings set default-web-browser "$desktop" || true
        set_mimes "$desktop" x-scheme-handler/http x-scheme-handler/https text/html ;;
    editor)
        selection="$(choose_installed 'Default editor' nvim Neovim code 'Visual Studio Code' zeditor Zed hx Helix helix Helix vim Vim emacs Emacs subl Sublime)"
        program="${selection%%$'\t'*}"; [[ -n "$program" ]] || exit 0
        printf '%s\n' "$program" >"$state_dir/editor"
        case "$program" in code) desktop=code.desktop ;; zeditor) desktop=dev.zed.Zed.desktop ;; emacs) desktop=emacs.desktop ;; subl) desktop=sublime_text.desktop ;; *) desktop= ;; esac
        [[ -n "$desktop" ]] && set_mimes "$desktop" text/plain text/markdown application/json ;;
    file-manager)
        selection="$(choose_installed 'Default file manager' thunar Thunar dolphin Dolphin nautilus Files nemo Nemo)"
        program="${selection%%$'\t'*}"; [[ -n "$program" ]] || exit 0
        printf '%s\n' "$program" >"$state_dir/file-manager"
        case "$program" in thunar) desktop=thunar.desktop ;; dolphin) desktop=org.kde.dolphin.desktop ;; nautilus) desktop=org.gnome.Nautilus.desktop ;; nemo) desktop=nemo.desktop ;; esac
        set_mimes "$desktop" inode/directory ;;
    pdf)
        selection="$(choose_installed 'Default PDF viewer' zathura Zathura evince 'Document Viewer' okular Okular)"
        program="${selection%%$'\t'*}"; [[ -n "$program" ]] || exit 0
        case "$program" in zathura) desktop=org.pwmt.zathura.desktop ;; evince) desktop=org.gnome.Evince.desktop ;; okular) desktop=org.kde.okular.desktop ;; esac
        set_mimes "$desktop" application/pdf ;;
    image)
        selection="$(choose_installed 'Default image viewer' imv imv loupe Loupe ristretto Ristretto feh feh)"
        program="${selection%%$'\t'*}"; [[ -n "$program" ]] || exit 0
        case "$program" in imv) desktop=imv.desktop ;; loupe) desktop=org.gnome.Loupe.desktop ;; ristretto) desktop=org.xfce.ristretto.desktop ;; feh) desktop=feh.desktop ;; esac
        set_mimes "$desktop" image/jpeg image/png image/webp image/gif image/avif ;;
    video)
        selection="$(choose_installed 'Default video player' mpv mpv vlc VLC celluloid Celluloid)"
        program="${selection%%$'\t'*}"; [[ -n "$program" ]] || exit 0
        case "$program" in mpv) desktop=mpv.desktop ;; vlc) desktop=vlc.desktop ;; celluloid) desktop=io.github.celluloid_player.Celluloid.desktop ;; esac
        set_mimes "$desktop" video/mp4 video/x-matroska video/webm video/quicktime ;;
    *) exit 0 ;;
esac

notify-send 'Defaults' "${selection#*$'\t'} is now the default."
