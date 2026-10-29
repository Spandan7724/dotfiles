#!/usr/bin/env bash
# Per-app graphics preference, like Windows' Graphics settings: everything
# runs on the integrated GPU, and apps marked "High performance" are started
# on the NVIDIA GPU (PRIME render offload) by the app launcher (Menu.qml).
# Choosing an app moves it between the two lists; it applies the next time
# the app is launched.
#
# The choice is kept in ~/.config/dotfiles/dgpu-apps.txt, one desktop id per
# line, which Menu.qml watches.

set -euo pipefail

list="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/dgpu-apps.txt"
hidden_list="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/panels/hidden-apps.txt"
menu="$HOME/.config/hypr/scripts/menu-select"

if [[ ! -f "$list" ]]; then
    mkdir -p "$(dirname "$list")"
    printf '%s\n' \
        '# Apps the launcher starts on the NVIDIA GPU, one desktop id per line.' \
        '# Edited by the Graphics menu (hypr/scripts/gpu-apps.sh).' >"$list"
fi

# Launchable apps as "id<TAB>Name<TAB>detail<TAB>icon" lines. User entries
# shadow system ones with the same id; NoDisplay, Hidden, and hidden-apps.txt
# entries are left out, as in the launcher.
desktop_apps() {
    local dirs=("${XDG_DATA_HOME:-$HOME/.local/share}/applications") data dir files=()
    IFS=: read -ra data <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for dir in "${data[@]}"; do dirs+=("$dir/applications"); done
    for dir in "${dirs[@]}"; do
        for file in "$dir"/*.desktop; do [[ -f "$file" ]] && files+=("$file"); done
    done
    ((${#files[@]})) || return 0
    awk '
        function flush() {
            if (id != "" && !seen[id]++ && !hidden && !nodisplay && name != "" && !(id in skip))
                print id "\t" name "\t" (generic != "" ? generic : comment) "\t" icon
        }
        FILENAME == ARGV[1] { sub(/#.*/, ""); gsub(/[ \t]+|\.desktop$/, ""); if ($0 != "") skip[$0]; next }
        FNR == 1 {
            flush()
            id = FILENAME; sub(/.*\//, "", id); sub(/\.desktop$/, "", id)
            main = 0; name = ""; generic = ""; comment = ""; icon = ""; hidden = 0; nodisplay = 0
        }
        /^\[/ { main = ($0 == "[Desktop Entry]"); next }
        !main { next }
        /^Name=/ && name == "" { name = substr($0, 6) }
        /^GenericName=/ && generic == "" { generic = substr($0, 13) }
        /^Comment=/ && comment == "" { comment = substr($0, 9) }
        /^Icon=/ && icon == "" { icon = substr($0, 6) }
        /^NoDisplay=true/ { nodisplay = 1 }
        /^Hidden=true/ { hidden = 1 }
        /^Type=/ && $0 != "Type=Application" { hidden = 1 }
        END { flush() }' <(cat "$hidden_list" 2>/dev/null) "${files[@]}"
}

apps="$(desktop_apps | sort -t $'\t' -k2,2f)"

# Rows as "Name<TAB>detail<TAB>icon<TAB>section<TAB>id", high performance
# apps first; the id is matched exactly from the last column.
rows() {
    awk -F '\t' -v OFS='\t' -v fast="High performance · NVIDIA GPU" -v saver='Power saving · Integrated GPU' '
        FILENAME == ARGV[1] { sub(/#.*/, ""); gsub(/[ \t]+|\.desktop$/, ""); if ($0 != "") on[$0]; next }
        { print ($1 in on ? 0 : 1), $2, $3, $4, ($1 in on ? fast : saver), $1 }' \
        "$list" - <<<"$apps" | sort -s -t $'\t' -k1,1n | cut -f2-
}

# Every launcher (Vicinae, Super+D, links opened from other apps) reads the
# desktop files, so the choice is applied there: a high performance app gets
# a copy in ~/.local/share/applications whose Exec lines go through
# prime-run. Copies made here are marked X-Dotfiles-dGPU=generated and are
# refreshed from the system file on every sync (after a package update the
# Exec line may have changed). An app that already had its own user copy is
# edited in place instead and marked X-Dotfiles-dGPU=edited.
user_apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

system_desktop_file() {
    local data dir
    IFS=: read -ra data <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for dir in "${data[@]}"; do
        [[ -f "$dir/applications/$1.desktop" ]] && { printf '%s\n' "$dir/applications/$1.desktop"; return; }
    done
    return 1
}

# Copies a desktop file with prime-run in front of every Exec, the marker
# added to the main section, and (for generated copies) D-Bus activation
# turned off, since that would start the app without the Exec line.
offload_file() {
    awk -v mark="$2" '
        /^Exec=/ && !/^Exec=prime-run / { sub(/^Exec=/, "Exec=prime-run ") }
        /^X-Dotfiles-dGPU=/ { next }
        mark == "generated" && /^DBusActivatable=/ { $0 = "DBusActivatable=false" }
        { print }
        $0 == "[Desktop Entry]" { print "X-Dotfiles-dGPU=" mark }' "$1"
}

offload_on() {
    local user="$user_apps/$1.desktop" system
    if [[ -f "$user" ]] && ! grep -qx 'X-Dotfiles-dGPU=generated' "$user"; then
        offload_file "$user" edited >"$user.tmp" && mv -- "$user.tmp" "$user"
    elif system="$(system_desktop_file "$1")"; then
        mkdir -p "$user_apps"
        offload_file "$system" generated >"$user.tmp" && mv -- "$user.tmp" "$user"
    fi
}

offload_off() {
    local user="$user_apps/$1.desktop"
    if grep -qx 'X-Dotfiles-dGPU=generated' "$user"; then
        rm -f -- "$user"
    else
        sed -i '/^X-Dotfiles-dGPU=/d; s/^Exec=prime-run /Exec=/' "$user"
    fi
}

sync_overrides() {
    local id file
    while IFS= read -r id; do
        offload_on "$id"
    done < <(sed 's/#.*//; s/[[:space:]]//g; s/\.desktop$//; /^$/d' "$list")
    for file in "$user_apps"/*.desktop; do
        [[ -f "$file" ]] && grep -q '^X-Dotfiles-dGPU=' "$file" || continue
        id="${file##*/}"; id="${id%.desktop}"
        grep -qxF -- "$id" "$list" || grep -qxF -- "$id.desktop" "$list" || offload_off "$id"
    done
    command -v update-desktop-database >/dev/null && update-desktop-database -q "$user_apps" || true
}

# At login (hyprland.lua) the overrides are just brought up to date.
if [[ "${1:-}" == --sync ]]; then
    sync_overrides
    exit 0
fi

selected=0
while :; do
    lines="$(rows)"
    selection="$("$menu" -no-custom -p 'Graphics' \
        -mesg 'Choose an app to switch its GPU. Applies the next time it starts.' \
        -display-columns 1 -detail-column 2 -icon-column 3 -section-column 4 \
        -selected-row "$selected" <<<"$lines")" || exit 0

    id="${selection##*$'\t'}"
    [[ -n "$id" && "$id" != "$selection" ]] || exit 0

    if grep -qxF -- "$id" "$list"; then
        grep -vxF -- "$id" "$list" >"$list.tmp" || true
        mv -- "$list.tmp" "$list"
    else
        printf '%s\n' "$id" >>"$list"
    fi
    sync_overrides

    # Reopen with the cursor on the app that just moved.
    selected="$(rows | awk -F '\t' -v id="$id" '$NF == id { print NR - 1; exit }')"
done
