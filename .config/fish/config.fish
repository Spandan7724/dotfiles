if status is-interactive
    starship init fish | source

    alias ls 'eza --icons'
    alias ll 'eza -lah --icons --git'
    alias la 'eza -a --icons'
    alias lt 'eza --tree --icons'

    alias reboot-windows '~/.config/hypr/scripts/reboot-windows.sh'
end

# Doom Emacs CLI and bun, when they are installed.
test -d ~/.config/emacs/bin; and fish_add_path --path ~/.config/emacs/bin
set --export BUN_INSTALL "$HOME/.bun"
test -d $BUN_INSTALL/bin; and fish_add_path --path $BUN_INSTALL/bin
