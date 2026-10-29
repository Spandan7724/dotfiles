eval "$(starship init zsh)"

alias ls='eza --icons'
alias ll='eza -lah --icons --git'
alias la='eza -a --icons'
alias lt='eza --tree --icons'

alias reboot-windows='~/.config/hypr/scripts/reboot-windows.sh'

autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors \
  '=(#b)*(=0)=38;5;250' \
  '=(#b)*(=1)=38;5;255' \
  '=(#b)*(=2)=38;5;245' \
  '=(#b)*(=3)=38;5;240'

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Highlighting and suggestion colours follow the desktop theme. The file is
# read again at the next prompt whenever it changes, so open shells pick up a
# theme switch too.
zmodload -F zsh/stat b:zstat
_dotfiles_theme_zsh="${XDG_CONFIG_HOME:-$HOME/.config}/themes/current/zsh.zsh"
_dotfiles_theme_stamp=
_dotfiles_theme_load() {
    local stamp
    stamp="$(zstat -L +mtime "$_dotfiles_theme_zsh" 2>/dev/null)$(zstat +mtime "$_dotfiles_theme_zsh" 2>/dev/null)"
    [[ -n "$stamp" && "$stamp" != "$_dotfiles_theme_stamp" ]] || return 0
    _dotfiles_theme_stamp="$stamp"
    source "$_dotfiles_theme_zsh"
}
_dotfiles_theme_load
autoload -Uz add-zsh-hook
add-zsh-hook precmd _dotfiles_theme_load
