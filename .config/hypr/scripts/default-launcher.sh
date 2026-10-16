#!/usr/bin/env bash
set -euo pipefail
kind="${1:-}"; shift || true
state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/defaults"
read_default() { local name="$1" fallback="$2"; if [[ -r "$state_dir/$name" ]]; then cat "$state_dir/$name"; else printf '%s' "$fallback"; fi; }
case "$kind" in
    terminal) exec "$(read_default terminal kitty)" "$@" ;;
    browser) exec "$(read_default browser zen-browser)" "$@" ;;
    file-manager) exec "$(read_default file-manager thunar)" "$@" ;;
    music)
        music="$(read_default music ncspot)"
        if ! command -v "$music" >/dev/null 2>&1; then
            notify-send 'Music player' "$music is not installed. Choose a music player in Defaults."
            exit 1
        fi
        case "$music" in
            ncspot|spotify_player|cmus|ncmpcpp|musikcube|termusic|kew|mocp)
                exec kitty --class dotfiles-ncspot --title "$music" -e "$music" "$@" ;;
            spotify|spotify-launcher)
                music_command="$music"
                # The scratchpad should open promptly. Keep installation and
                # update checks available when launching spotify-launcher normally.
                if [[ "$music" == spotify-launcher && -x "${XDG_DATA_HOME:-$HOME/.local/share}/spotify-launcher/install/usr/bin/spotify" ]]; then
                    music_command+=' --skip-update'
                fi
                # Reuse Spotify if it is already running; otherwise apply
                # scratchpad rules to the window created by the launcher.
                exec hyprctl eval "
                    for _, w in ipairs(hl.get_windows()) do
                        if w.class:lower() == 'spotify' then
                            hl.dispatch(hl.dsp.window.move({ window = w, workspace = 'special:ncspot', follow = false }))
                            if w.fullscreen == 2 then
                                hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = 'fullscreen', action = 'toggle' }))
                            end
                            if w.fullscreen ~= 1 then
                                hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = 'maximized', action = 'toggle' }))
                            end
                            return
                        end
                    end
                    hl.exec_cmd('$music_command', { workspace = 'special:ncspot', maximize = true })" ;;
            *) notify-send 'Music player' 'Choose a supported music player in Defaults.'; exit 2 ;;
        esac ;;
    editor) editor="$(read_default editor nvim)"; case "$editor" in nvim|vim|hx|helix) exec "$(read_default terminal kitty)" -e "$editor" "$@" ;; *) exec "$editor" "$@" ;; esac ;;
    notes)
        # doom and nvim start a new Markdown note in ~/notes (created on first
        # save); app:<desktop-id> launches a notes app picked in defaults-menu.sh.
        notes="$(read_default notes doom)"
        mkdir -p "$HOME/notes"
        note="$HOME/notes/$(date '+%Y-%m-%d_%H-%M-%S').md"
        case "$notes" in
            doom) exec emacsclient -c -a '' "$note" ;;
            nvim) exec "$(read_default terminal kitty)" -e nvim "$note" ;;
            app:*) exec gtk-launch "${notes#app:}" ;;
            *) exit 2 ;;
        esac ;;
    *) exit 2 ;;
esac
