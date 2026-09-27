#!/usr/bin/env bash
#
# The central desktop menu.
#
# The whole menu is one declarative table (see MENU below) rendered by a single
# generic pass. Selection dispatches on the hidden id column, never on the
# visible label, so rewording a row can never break its action.
#
# Labels are one or two words. Everything a person might type instead lives in
# the keywords column, which is searched but never shown.
#
# Usage: desktop-menu.sh [route]   e.g. desktop-menu.sh power

set -uo pipefail

scripts="$HOME/.config/hypr/scripts"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
menu_theme="$config_root/rofi/menu.rasi"

# Pressing the menu key while the menu is up closes it instead of stacking a
# second copy on top of the first.
if [[ "${1:-}" != --no-toggle ]] && pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi
[[ "${1:-}" == --no-toggle ]] && shift

# --- menu table ------------------------------------------------------------
#
# parent | id | icon | label | keywords | action | when
#
#   action  ">id" opens that submenu, anything else runs as a shell command.
#   keywords are searchable but never displayed.
#   when    optional shell test; the row is hidden when it fails.
#
# Fields are pipe-separated, so an action that needs a pipe goes in a helper
# function above and is called by name here.

read -r -d '' MENU <<'TABLE'
root|apps|󰀻|Apps|applications launcher programs software run drun|rofi -show drun -modi drun -p Apps|
root|search|󰍉|Search|everything windows commands run combi switch alt tab|rofi -show combi -modi combi,drun,window,run -p Search|
root|overview|󰘔|Overview|workspaces windows expo grid desktops|$scripts/workspace-overview.sh toggle|
root|capture|󰄀|Capture||>capture|
root|style|󰏘|Style||>style|
root|setup|󰒓|Setup||>setup|
root|tools|󰧑|Tools||>tools|
root|keybinds|󰌌|Keybindings|shortcuts hotkeys keys bindings cheatsheet help|$scripts/keybinds.sh|
root|power|󰐥|Power||>power|

capture|capture-shot|󰹑|Screenshot|screenshot picture grab snip print screen|>capture-shot|
capture|capture-record|󰑊|Screenrecord|record video capture mp4 screencast movie|$scripts/record-toggle.sh|command -v wf-recorder
capture|capture-ocr|󰴑|Text|ocr scan read copy text from screen tesseract|$scripts/screenshot.sh ocr|command -v tesseract
capture|capture-colour|󰃉|Colour|color picker eyedropper hex hyprpicker swatch|$scripts/color-picker.sh|command -v hyprpicker

capture-shot|shot-region|󰩭|Region|select area crop snip part|$scripts/screenshot.sh area|
capture-shot|shot-window|󰖯|Window|active current application|$scripts/screenshot.sh window|
capture-shot|shot-full|󰍹|Full screen|fullscreen whole display everything monitor|$scripts/screenshot.sh full|
capture-shot|shot-delay|󰔛|Delayed|after 5 seconds timer wait countdown|$scripts/screenshot.sh delay|
capture-shot|shot-annotate|󰏬|Annotate|draw markup arrow swappy edit|$scripts/screenshot.sh annotate|command -v swappy
capture-shot|shot-copy|󰅍|To clipboard|copy paste region without saving|$scripts/screenshot.sh area-copy|

style|style-theme|󰸌|Theme|gruvbox everforest tokyo night monochrome colours scheme palette|$config_root/themes/picker.sh|
style|style-wallpaper|󰸉|Wallpaper|background image picture photo desktop|>style-wallpaper|
style|style-opacity|󰡱|Opacity|transparency see through faded window|$scripts/opacity.sh|
style|style-bar|󰍜|Menu bar|menubar waybar panel status hide show toggle|$scripts/waybar-toggle.sh|
style|style-reload|󰑐|Reload|refresh restart hyprland waybar config apply|$scripts/reload-desktop.sh|

style-wallpaper|wall-choose|󰸉|Choose|pick browse select background image|quickshell -n -c hyprquickpaper|
style-wallpaper|wall-next|󰒭|Next|forward cycle following background|$scripts/wallpaper-cycle.sh next|
style-wallpaper|wall-prev|󰒮|Previous|back cycle prior background|$scripts/wallpaper-cycle.sh previous|
style-wallpaper|wall-random|󰒟|Random|shuffle surprise any background|$scripts/wallpaper-cycle.sh random|

setup|setup-defaults|󰉋|Defaults|default applications terminal shell browser editor file manager pdf image video|$scripts/defaults-menu.sh|
setup|setup-network|󰤨|Wi-Fi|wifi network internet ethernet vpn connection wireless|nm-connection-editor|command -v nm-connection-editor
setup|setup-bluetooth|󰂯|Bluetooth|pair device headphones mouse keyboard|blueman-manager|command -v blueman-manager
setup|setup-audio|󰕾|Audio|sound volume microphone output input pavucontrol|pavucontrol|command -v pavucontrol
setup|setup-brightness|󰃠|Brightness|backlight dim screen light display|menu_brightness|command -v brightnessctl
setup|setup-night|󰖔|Night light|nightlight blue gamma warm temperature gammastep|$config_root/waybar/scripts/toggle-gammastep|test -x $config_root/waybar/scripts/toggle-gammastep
setup|setup-idle|󰡆|Screen & lock|idle timeout screensaver sleep blank dim dpms lock screen awake suspend inactivity|$scripts/idle-settings.sh|
setup|setup-displays|󰍹|Displays|monitors resolution scale arrangement nwg|nwg-displays|command -v nwg-displays
setup|setup-power|󰂏|Power profile|battery performance balanced saver watts gpu|$scripts/power-profile.sh menu|command -v powerprofilesctl
setup|setup-packages|󰏖|Packages|install remove update pacman yay aur orphans software|$scripts/package-manager.sh|
setup|setup-vm|󰢹|Virtual machines|vm qemu kvm libvirt virt-manager iso distro|$scripts/vm-manager.sh|command -v virsh
setup|setup-fingerprint|󰈷|Fingerprint|biometric enroll unlock security fprintd|kitty --class dotfiles-security --title 'Fingerprint setup' -e $scripts/fingerprint-setup.sh|command -v fprintd-enroll
setup|setup-hyprland|󰖲|Hyprland|hyprmod compositor configuration advanced tweak|$scripts/hyprmod-launch.sh|command -v hyprmod

tools|tools-clipboard|󰅌|Clipboard|history copy paste text image cliphist|$scripts/clipboard.sh|command -v cliphist
tools|tools-calculator|󰪚|Calculator|math qalc compute sum convert units|$scripts/calculator.sh|
tools|tools-emoji|󰞅|Emoji|symbols glyph character unicode rofimoji|rofimoji --action copy|command -v rofimoji
tools|tools-files|󰈙|Files|search find documents folders open|$scripts/file-search.sh|
tools|tools-web|󰖟|Web|search google query browser internet|$scripts/web-search.sh|
tools|tools-transcode|󰕧|Transcode|convert video image mp4 gif compress shrink|$scripts/transcode.sh|
tools|tools-monitor|󰍛|Monitor|system btop cpu memory process top usage|kitty --class dotfiles-btop -e btop|command -v btop

power|power-lock|󰌾|Lock|lockscreen hyprlock secure screen|hyprlock|
power|power-suspend|󰤄|Suspend|sleep standby ram|systemctl suspend|
power|power-hibernate|󰒲|Hibernate|sleep disk swap resume|do_hibernate|hibernation_available
power|power-logout|󰍃|Log out|logout signout exit session sign out quit hyprland|uwsm stop|
power|power-restart|󰜉|Restart|reboot|systemctl reboot|
power|power-windows|󰖳|Windows|reboot restart boot into windows dual boot bitlocker bootnext uefi|$scripts/reboot-windows.sh|test -x /usr/local/libexec/dotfiles-reboot-windows-root
power|power-shutdown|󰐥|Shut down|shutdown poweroff halt turn off|systemctl poweroff|
TABLE

# --- helpers used as actions ----------------------------------------------

# zram cannot hold a hibernation image, so the row is only offered when a real
# swap device exists and the kernel advertises suspend-to-disk.
hibernation_available() {
    grep -q disk /sys/power/state &&
        swapon --show=NAME --noheadings 2>/dev/null | grep -qv '^/dev/zram'
}

do_hibernate() {
    systemctl hibernate ||
        notify-send -u critical 'Hibernate failed' 'Check that swap and the resume kernel parameter are configured.'
}

menu_brightness() {
    local choice
    choice="$(printf '%s\n' '10%' '25%' '50%' '75%' '100%' |
        rofi -dmenu -i -no-custom -p 'Brightness' -theme "$menu_theme")" || return 0
    [[ -n "$choice" ]] && brightnessctl set "$choice"
}

# --- model -----------------------------------------------------------------

# ACTION maps a row id to what it does. SECTION / SECTION_PARENT describe the
# submenu routes, which are named by the rows that open them rather than by
# rows of their own.
declare -A ACTION SECTION SECTION_PARENT


# The table is written with literal $scripts / $config_root so it stays readable;
# expand them once here rather than eval-ing the table.
MENU="${MENU//\$scripts/$scripts}"
MENU="${MENU//\$config_root/$config_root}"

while IFS='|' read -r parent id icon label keywords action when; do
    [[ -n "$parent" && "$parent" != \#* ]] || continue
    ACTION["$id"]="$action"
    # A row that opens a submenu also names it, which is what breadcrumbs and
    # the root index show. Submenu ids themselves are never rows.
    if [[ "$action" == '>'* ]]; then
        SECTION["${action#>}"]="$label"
        SECTION_PARENT["${action#>}"]="$parent"
    fi
done <<<"$MENU"

available() {
    local when="$1"
    [[ -z "$when" ]] && return 0
    eval "$when" >/dev/null 2>&1
}

# --- rows ------------------------------------------------------------------
#
# A row is "<label>\t<submenu?>\t<id>\t<keywords>". rofi returns the whole row
# and displays only the first column, so the id survives the round trip
# untouched. align_rows folds the second column into the first once the widest
# label is known, leaving rofi the three columns it expects.

# A row is "<label>\t<kind>\t<detail>\t<id>\t<keywords>". rofi returns the whole
# row and displays only the first column, so the id survives the round trip
# untouched. compose() folds kind and detail into the first column once the
# widest label is known.

emit() { # emit <icon> <label> <kind> <detail> <id> <keywords>
    printf '%s  %s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6"
}

rows_for() {
    local node="$1" parent id icon label keywords action when kind
    while IFS='|' read -r parent id icon label keywords action when; do
        [[ "$parent" == "$node" ]] || continue
        available "$when" || continue
        kind=''
        [[ "$action" == '>'* ]] && kind=submenu
        emit "$icon" "$label" "$kind" "" "$id" "$keywords"
    done <<<"$MENU"
}

# The root also indexes every action in the tree, so typing a leaf's name finds
# the leaf itself rather than the category that happens to contain it. The root
# category rows above carry no keywords on purpose: a category matching "theme"
# or "ocr" would rank alongside the leaf that actually does that thing, which is
# the whole problem the index exists to solve. They still match their own label.
#
# An indexed row leads with its own name and carries the path it came from
# underneath, the way the Omarchy menu does it — the thing you are looking for
# reads first, and the breadcrumb only says where it lives.
rows_root() {
    local parent id icon label keywords action when detail
    rows_for root
    # Sorted on the label rather than the emitted row, whose leading icon glyph
    # would otherwise decide the order.
    while IFS='|' read -r parent id icon label keywords action when; do
        [[ -n "$parent" && "$parent" != root ]] || continue
        [[ "$action" == '>'* ]] && continue
        available "$when" || continue
        printf '%s|%s|%s|%s|%s\n' "$label" "$(breadcrumb "$parent")" "$icon" "$id" "$keywords"
    done <<<"$MENU" | sort -f | while IFS='|' read -r label detail icon id keywords; do
        emit "$icon" "$label" index "$detail" "$id" "$keywords"
    done
}

# Pad the labels out to the widest one so submenu chevrons line up in a column
# of their own, then hang each row's detail under it as dim Pango markup. Only
# rows belonging to the route itself set that width: the root's index of the
# whole tree would otherwise push the chevrons far off to the right.
compose() {
    awk -F'\t' -v markup="${1:-0}" '
        function esc(t) { gsub(/&/, "\\&amp;", t); gsub(/</, "\\&lt;", t); gsub(/>/, "\\&gt;", t); return t }
        { rows[NR] = $0; if ($2 != "index" && length($1) > width) width = length($1) }
        END {
            for (i = 1; i <= NR; i++) {
                split(rows[i], f, "\t")
                label = f[1]
                if (f[2] == "submenu") label = sprintf("%-*s  ›", width, label)
                if (markup == 1) {
                    label = esc(label)
                    if (f[3] != "")
                        printf "%s\n<span alpha=\"45%%\"><small>%s</small></span>", label, esc(f[3])
                    else
                        printf "%s", label
                } else {
                    printf "%s", label
                }
                printf "\t%s\t%s", f[4], f[5]
                printf "%c", (markup == 1) ? 0 : 10
            }
        }'
}

breadcrumb() {
    local node="$1" trail=""
    while [[ "$node" != root && -n "$node" ]]; do
        trail="${SECTION[$node]:-$node}${trail:+ › $trail}"
        node="${SECTION_PARENT[$node]:-root}"
    done
    printf '%s' "${trail:-Desktop}"
}

render() {
    local node="$1" rows count list status

    if [[ "$node" == root ]]; then
        # Two-line rows need Pango markup for the dim second line, which means
        # rows can no longer be newline-separated; -eh 2 gives them the height
        # to actually show it. The NUL-separated list goes through a file
        # because command substitution silently drops NUL bytes.
        list="$(mktemp -t desktop-menu.XXXXXX)"
        trap 'rm -f -- "$list"' RETURN
        rows_root | compose 1 >"$list"
        [[ -s "$list" ]] || return 1
        count="$(tr -cd '\0' <"$list" | wc -c)"
        ((count > 7)) && count=7
        rofi -dmenu -i -no-custom -markup-rows -sep '\0' -eh 2 \
            -p "$(breadcrumb "$node")" -display-columns 1 -theme "$menu_theme" \
            -theme-str "listview { lines: $count; }" <"$list"
        return $?
    fi

    rows="$(rows_for "$node" | compose 0)"
    [[ -n "$rows" ]] || return 1
    count="$(printf '%s\n' "$rows" | wc -l)"
    ((count > 9)) && count=9
    printf '%s\n' "$rows" | rofi -dmenu -i -no-custom \
        -p "$(breadcrumb "$node")" -display-columns 1 -theme "$menu_theme" \
        -theme-str "listview { lines: $count; }"
}

# --- navigation ------------------------------------------------------------

declare -a stack=("${1:-root}")

while ((${#stack[@]})); do
    node="${stack[-1]}"
    selection="$(render "$node")"
    status=$?

    # Killed rather than cancelled: the menu key was pressed again, or the
    # session is going away. Close the whole menu instead of walking back up it.
    ((status >= 128)) && exit 0

    if ((status != 0)) || [[ -z "$selection" ]]; then
        # Escape, or an empty route: step back out one level.
        unset 'stack[-1]'
        continue
    fi

    id="${selection#*$'\t'}"
    id="${id%%$'\t'*}"
    action="${ACTION[$id]:-}"

    case "$action" in
        '') unset 'stack[-1]' ;;
        '>'*) stack+=("${action#>}") ;;
        *)
            if [[ "$(type -t "${action%% *}")" == function ]]; then
                "$action"
            else
                setsid -f bash -c "$action" >/dev/null 2>&1
            fi
            exit 0
            ;;
    esac
done
