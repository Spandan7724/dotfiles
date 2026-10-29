#!/usr/bin/env bash

set -euo pipefail
state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/defaults"
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

menu="$HOME/.config/hypr/scripts/menu-select"

# Every launcher, as "desktop-id<TAB>Name<TAB>MimeType<TAB>text<TAB>listed"
# lines, read once up front. User entries shadow system ones with the same id
# (a hidden user copy hides the app), text is the lowercased name,
# description, keywords, and categories, and listed is 0 for NoDisplay
# entries, which still count as file handlers but not as apps to launch.
desktop_entries() {
    local dirs=("${XDG_DATA_HOME:-$HOME/.local/share}/applications") data dir files=()
    IFS=: read -ra data <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for dir in "${data[@]}"; do dirs+=("$dir/applications"); done
    for dir in "${dirs[@]}"; do
        for file in "$dir"/*.desktop; do [[ -f "$file" ]] && files+=("$file"); done
    done
    ((${#files[@]})) || return 0
    awk '
        function flush() {
            if (id != "" && !seen[id]++ && !hidden && name != "") print id "\t" name "\t" mime "\t" text "\t" !nodisplay
        }
        FNR == 1 {
            flush()
            id = FILENAME; sub(/.*\//, "", id); sub(/\.desktop$/, "", id)
            main = 0; name = ""; mime = ""; text = ""; hidden = 0; nodisplay = 0
        }
        /^\[/ { main = ($0 == "[Desktop Entry]"); next }
        !main { next }
        /^Name=/ && name == "" { name = substr($0, 6) }
        /^MimeType=/ { mime = substr($0, 10) }
        /^NoDisplay=true/ { nodisplay = 1 }
        /^Hidden=true/ { hidden = 1 }
        /^Type=/ && $0 != "Type=Application" { hidden = 1 }
        /^(Name|GenericName|Keywords|Comment|Categories)=/ { text = text " " tolower($0) }
        END { flush() }' "${files[@]}"
}
entries="$(desktop_entries)"

# Installed notes apps, as "desktop-id<TAB>Name" lines. Any launcher whose
# name, description, keywords, or categories talk about notes, notebooks,
# journals, or a knowledge base counts, so apps such as Obsidian, Logseq, or
# Joplin appear here once installed (including Flatpaks) with no list to edit.
notes_apps() {
    awk -F '\t' '$5 && $4 ~ /(^|[^a-z])(notes?|notebook|note-taking|notetaking|zettelkasten|journal|knowledge base|second brain)([^a-z]|$)/ { print $1 "\t" $2 }' \
        <<<"$entries" | sort -t $'\t' -k2,2
}

# Apps that say they open any of the MIME types on stdin, as
# "desktop-id<TAB>Name" lines sorted by name.
mime_apps() {
    awk -F '\t' 'NR == FNR { if ($0 != "") want[$0] = 1; next }
        { n = split($3, m, ";"); for (i = 1; i <= n; i++) if (m[i] in want) { print $1 "\t" $2; next } }' \
        - <(printf '%s\n' "$entries") | sort -t $'\t' -k2,2
}

# An app's name from its desktop id.
app_name() {
    awk -F '\t' -v id="$1" '$1 == id { print $2; exit }' <<<"$entries"
}

# The MIME types one app says it opens, one per line.
app_mimes() {
    awk -F '\t' -v id="$1" '$1 == id { gsub(";", "\n", $3); printf "%s", $3; exit }' <<<"$entries"
}

# Every file type some installed app opens, as "description<TAB>detail<TAB>
# icon<TAB>type" rows for the menu. The detail lists the file extensions
# (so typing "docx" finds Word files) and the app that opens it now.
file_types() {
    local db=/usr/share/mime/packages/freedesktop.org.xml mimeapps="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
    awk -F '\t' '
        FILENAME == "-" { n = split($3, m, ";"); for (i = 1; i <= n; i++) if (m[i] != "") handled[m[i]] = 1
                          app[$1 ".desktop"] = $2; next }
        FILENAME ~ /mimeapps/ {
            if (/^\[/) { defaults = ($0 == "[Default Applications]"); next }
            if (defaults && (eq = index($0, "="))) { d = substr($0, eq + 1); sub(/;.*/, "", d); now[substr($0, 1, eq - 1)] = d }
            next
        }
        /<mime-type type="/ { type = $0; sub(/.*type="/, "", type); sub(/".*/, "", type); exts = "" }
        /<comment>/ && !(type in comment) { c = $0; sub(/.*<comment>/, "", c); sub(/<\/comment>.*/, "", c)
                                            gsub(/&amp;/, "\\&", c); comment[type] = c }
        /<glob pattern="\*\.[^"*]*"/ { g = $0; sub(/.*pattern="\*/, "", g); sub(/".*/, "", g)
                                        exts = exts (exts == "" ? "" : " ") g }
        /<\/mime-type>/ { ext[type] = exts }
        END {
            for (t in handled) {
                if (t ~ /^x-scheme-handler\//) continue
                detail = (ext[t] != "" ? ext[t] : t)
                if (t in now) detail = detail "  ·  " (now[t] in app ? app[now[t]] : now[t])
                icon = t; sub("/", "-", icon)
                print (t in comment ? comment[t] : t) "\t" detail "\t" icon "\t" t
            }
        }' - "$mimeapps" "$db" <<<"$entries" | sort -f -t $'\t' -k1,1
}

# The choices for a category as "program<TAB>label<TAB>desktop<TAB>detail"
# lines. The program is what gets stored; the desktop file (blank when there
# is none) sets file associations and supplies the icon.
choices() {
    case "$1" in
        terminal) printf '%s\t%s\t%s\t\n' kitty Kitty kitty.desktop foot Foot foot.desktop \
            alacritty Alacritty Alacritty.desktop ghostty Ghostty com.mitchellh.ghostty.desktop \
            wezterm WezTerm org.wezfurlong.wezterm.desktop ;;
        shell) printf '%s\t%s\t\t\n' fish Fish zsh Zsh bash Bash ;;
        browser) printf '%s\t%s\t%s\t\n' zen-browser 'Zen Browser' zen.desktop brave Brave brave-browser.desktop \
            brave-browser Brave brave-browser.desktop firefox Firefox firefox.desktop \
            chromium Chromium chromium.desktop google-chrome-stable Chrome google-chrome.desktop ;;
        editor) printf '%s\t%s\t%s\t\n' nvim Neovim '' code 'Visual Studio Code' code.desktop \
            zeditor Zed dev.zed.Zed.desktop hx Helix '' helix Helix '' vim Vim '' \
            emacs Emacs emacs.desktop subl Sublime sublime_text.desktop ;;
        file-manager) printf '%s\t%s\t%s\t\n' thunar Thunar thunar.desktop dolphin Dolphin org.kde.dolphin.desktop \
            nautilus Files org.gnome.Nautilus.desktop nemo Nemo nemo.desktop ;;
        notes)
            printf 'doom\tDoom Emacs\temacs.desktop\tNew note in ~/notes\n'
            printf 'nvim\tNeovim\tnvim.desktop\tNew note in ~/notes\n'
            notes_apps | awk -F '\t' '{ print "app:" $1 "\t" $2 "\t" $1 ".desktop\t" }' ;;
        agent) printf '%s\t%s\t\t\n' claude 'Claude Code' codex Codex opencode OpenCode amp Amp mu Mu ;;
        music) printf '%s\t%s\t%s\t\n' ncspot ncspot ncspot.desktop \
            spotify-launcher Spotify spotify-launcher.desktop spotify Spotify spotify.desktop \
            spotify_player 'Spotify Player' '' cmus cmus '' ncmpcpp ncmpcpp '' \
            musikcube musikcube '' termusic termusic '' kew kew '' mocp 'Music on Console' '' ;;
        # File types list every installed app that says it opens them.
        pdf | image | video | audio | document | spreadsheet | presentation | ebook | archive | mime:*)
            mimes "$1" | mime_apps | awk -F '\t' '{ print "app:" $1 "\t" $2 "\t" $1 ".desktop\t" }' ;;
    esac
}

installed() {
    case "$1" in
        doom) command -v emacsclient >/dev/null 2>&1 ;;
        app:*) true ;;
        *) command -v "$1" >/dev/null 2>&1 ;;
    esac
}

# The MIME types a category's default opens.
mimes() {
    case "$1" in
        browser) printf '%s\n' x-scheme-handler/http x-scheme-handler/https text/html ;;
        editor) printf '%s\n' text/plain text/markdown application/json ;;
        file-manager) printf '%s\n' inode/directory ;;
        pdf) printf '%s\n' application/pdf ;;
        image) printf '%s\n' image/jpeg image/png image/webp image/gif image/avif image/bmp image/tiff image/svg+xml ;;
        video) printf '%s\n' video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg ;;
        audio) printf '%s\n' audio/mpeg audio/flac audio/ogg audio/x-vorbis+ogg audio/opus audio/x-wav audio/wav \
            audio/mp4 audio/aac audio/x-m4a ;;
        document) printf '%s\n' application/vnd.openxmlformats-officedocument.wordprocessingml.document \
            application/msword application/vnd.oasis.opendocument.text application/rtf text/rtf ;;
        spreadsheet) printf '%s\n' application/vnd.openxmlformats-officedocument.spreadsheetml.sheet \
            application/vnd.ms-excel application/vnd.oasis.opendocument.spreadsheet text/csv ;;
        presentation) printf '%s\n' application/vnd.openxmlformats-officedocument.presentationml.presentation \
            application/vnd.ms-powerpoint application/vnd.oasis.opendocument.presentation ;;
        ebook) printf '%s\n' application/epub+zip application/x-mobipocket-ebook application/vnd.comicbook+zip ;;
        archive) printf '%s\n' application/zip application/x-tar application/x-compressed-tar application/x-7z-compressed \
            application/vnd.rar application/x-rar application/gzip application/x-xz-compressed-tar application/zstd ;;
        mime:*) printf '%s\n' "${1#mime:}" ;;
    esac
}

# The program currently chosen for a category, or nothing. Unset app
# categories fall back to the same defaults as default-launcher.sh.
current() {
    local category="$1" desktop=""
    case "$category" in
        shell) basename "$(getent passwd "$USER" | cut -d: -f7)"; return ;;
        terminal | browser | editor | file-manager | notes | agent | music)
            if [[ -s "$state_dir/$category" ]]; then cat -- "$state_dir/$category"; return; fi
            case "$category" in
                terminal) printf 'kitty\n' ;; browser) printf 'zen-browser\n' ;; editor) printf 'nvim\n' ;;
                file-manager) printf 'thunar\n' ;; notes) printf 'doom\n' ;;
                music) printf 'ncspot\n' ;;
            esac
            return ;;
    esac
    # File types: what opens the first of the category's MIME types that has
    # a default.
    local mime
    while read -r mime; do
        desktop="$(xdg-mime query default "$mime" 2>/dev/null || true)"
        [[ -n "$desktop" ]] && { printf 'app:%s\n' "${desktop%.desktop}"; break; }
    done < <(mimes "$category")
    return 0
}

field() { # field <category> <program> <column>
    choices "$1" | awk -F '\t' -v p="$2" -v n="$3" '!found && $1 == p { print $n; found = 1 }'
}

set_mimes() {
    local desktop="$1" mime
    while read -r mime; do xdg-mime default "$desktop" "$mime"; done
}

# Pick a program for a category. Rows are "label, detail, icon, program"; the
# current choice is marked and the program is read from the last column.
choose() { # choose <category> <title>
    local category="$1" title="$2" now
    now="$(current "$category")"
    choices "$category" | while IFS=$'\t' read -r program label desktop detail; do
        installed "$program" || continue
        local marker='' icon="${desktop%.desktop}"
        [[ "$program" == "$now" ]] && marker='● '
        # Shells and CLI agents have no desktop entry, so they get a glyph.
        [[ -z "$icon" && "$category" == shell ]] && icon=$'\U000f018d'
        [[ -z "$icon" && "$category" == agent ]] && icon=$'\U000f140b'
        [[ -z "$icon" && "$category" == music ]] && icon=$'\U000f075a'
        printf '%s%s\t%s\t%s\t%s\n' "$marker" "$label" "${detail:-${program#app:}}" "${icon:-$program}" "$program"
    done | "$menu" -no-custom -p "$title" -display-columns 1 -detail-column 2 -icon-column 3 |
        awk -F '\t' '{ print $NF }'
}

# Each category with what it is set to now. Rows are "label, current default,
# icon, section, id"; the id is the last column.
category="$({
    row() { # row <id> <icon> <label> <section>
        local now label
        # Skip file types nothing installed can open.
        [[ -n "$(mimes "$1")" && -z "$(choices "$1")" ]] && return
        now="$(current "$1")"
        label="$(field "$1" "$now" 2)"
        [[ -z "$label" && "$now" == app:* ]] && label="$(app_name "${now#app:}")"
        now="${now#app:}"
        printf '%s\t%s\t%b\t%s\t%s\n' "$3" "${label:-${now:-Not set}}" "$2" "$4" "$1"
    }
    row terminal '\U000f018d' 'Terminal' 'Apps'
    row shell '\U000f07b7' 'Login shell' 'Apps'
    row browser '\U000f059f' 'Web browser' 'Apps'
    row editor '\U000f0a1e' 'Code and text editor' 'Apps'
    row file-manager '\U000f024b' 'File manager' 'Apps'
    row notes '\U000f082e' 'Notes app' 'Apps'
    row agent '\U000f140b' 'Coding agent' 'Apps'
    row music '\U000f075a' 'Music player (Win+H)' 'Apps'
    row pdf '\U000f0226' 'PDF viewer' 'Files'
    row image '\U000f02e9' 'Image viewer' 'Files'
    row video '\U000f0439' 'Video player' 'Files'
    row audio '\U000f0388' 'Audio player' 'Files'
    row document '\U000f022c' 'Word documents' 'Files'
    row spreadsheet '\U000f021b' 'Spreadsheets' 'Files'
    row presentation '\U000f0227' 'Presentations' 'Files'
    row ebook '\U000f00ba' 'E-books' 'Files'
    row archive '\U000f05c4' 'Archives' 'Files'
    printf '%s\t%s\t%b\t%s\t%s\n' 'Other file type' 'Any type, search by name or extension' '\U000f0214' 'Files' other
} | "$menu" -no-custom -p 'Defaults' -display-columns 1 -detail-column 2 -icon-column 3 -section-column 4)" || exit 0
category="${category##*$'\t'}"

case "$category" in
    terminal) title='Default terminal' ;;
    shell) title='Login shell' ;;
    browser) title='Default browser' ;;
    editor) title='Default editor' ;;
    file-manager) title='Default file manager' ;;
    notes) title='Notes app' ;;
    agent) title='Coding agent' ;;
    music) title='Music player (Win+H)' ;;
    pdf) title='Default PDF viewer' ;;
    image) title='Default image viewer' ;;
    video) title='Default video player' ;;
    audio) title='Default audio player' ;;
    document) title='Word documents' ;;
    spreadsheet) title='Spreadsheets' ;;
    presentation) title='Presentations' ;;
    ebook) title='E-books' ;;
    archive) title='Archives' ;;
    other)
        type="$(file_types | "$menu" -no-custom -p 'File type' -display-columns 1 -detail-column 2 -icon-column 3)" || exit 0
        title="${type%%$'\t'*}"
        category="mime:${type##*$'\t'}" ;;
    *) exit 0 ;;
esac
program="$(choose "$category" "$title")" || exit 0
[[ -n "$program" ]] || exit 0
desktop="$(field "$category" "$program" 3)"

case "$category" in
    shell)
        exec kitty --class dotfiles-defaults --title 'Change login shell' -e "$0" --set-shell "$program" ;;
    terminal)
        printf '%s\n' "$program" >"$state_dir/terminal"
        printf '%s\n' "$desktop" >"${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list" ;;
    browser)
        printf '%s\n' "$program" >"$state_dir/browser"
        xdg-settings set default-web-browser "$desktop" || true
        mimes browser | set_mimes "$desktop" ;;
    editor | file-manager)
        printf '%s\n' "$program" >"$state_dir/$category"
        [[ -n "$desktop" ]] && mimes "$category" | set_mimes "$desktop" ;;
    notes | agent | music)
        printf '%s\n' "$program" >"$state_dir/$category" ;;
    *)
        # Only the types the app says it opens, so picking a viewer that
        # handles PNG but not SVG leaves SVG alone.
        mimes "$category" | grep -Fxf <(app_mimes "${program#app:}") | set_mimes "$desktop" || true ;;
esac

if [[ "$category" == music ]]; then
    notify-send 'Defaults' "$(field "$category" "$program" 2) is now the music player. Close the current music window to use it next time you press Win+H."
else
    notify-send 'Defaults' "$(field "$category" "$program" 2) is now the default."
fi
