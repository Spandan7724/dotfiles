#!/usr/bin/env bash
#
# Transcode a picture or video for sharing.
#
# Usage: transcode.sh [file]
#        transcode.sh --run <file> <format> <resolution>   (internal)

set -euo pipefail


media_type() {
    case "$(file -b --mime-type "$1")" in
        image/*) printf image ;;
        video/*) printf video ;;
        *) return 1 ;;
    esac
}

run_transcode() {
    local input="$1" format="$2" resolution="$3" type output stem directory resize scale
    type="$(media_type "$input")"
    directory="$(dirname -- "$input")"
    stem="$(basename -- "${input%.*}")"
    output="$directory/$stem-$resolution.$format"

    if [[ "$type" == image ]]; then
        case "$resolution" in high) resize='3160x>' ;; medium) resize='2160x>' ;; low) resize='1080x>' ;; esac
        if [[ "$format" == jpg ]]; then
            magick "$input" -resize "$resize" -quality 85 -strip "$output"
        else
            # Omarchy's PNG settings: the default encoder leaves a lot on the table.
            magick "$input" -resize "$resize" -strip \
                -define png:compression-filter=5 \
                -define png:compression-level=9 \
                -define png:compression-strategy=1 \
                -define png:exclude-chunk=all \
                "$output"
        fi
    else
        case "$resolution" in 4k) scale='scale=-2:2160' ;; 1080p) scale='scale=-2:1080' ;; 720p) scale='scale=-2:720' ;; esac
        if [[ "$format" == gif ]]; then
            ffmpeg -hide_banner -i "$input" \
                -vf "fps=10,$scale:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" "$output"
        elif [[ "$resolution" == 4k ]]; then
            # H.265 at 4K: H.264 files that size are unwieldy to share.
            ffmpeg -hide_banner -i "$input" -vf "$scale" \
                -c:v libx265 -preset slow -crf 24 -c:a aac -b:a 192k -movflags +faststart "$output"
        else
            ffmpeg -hide_banner -i "$input" -vf "$scale" \
                -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 192k -movflags +faststart "$output"
        fi
    fi

    printf 'file://%s\n' "$(realpath -- "$output")" | wl-copy --type text/uri-list
    notify-send -a Transcode 'Transcode complete' "$(basename -- "$output") was saved and copied."
}

if [[ "${1:-}" == --run ]]; then
    run_transcode "$2" "$3" "$4"
    printf '\nFinished. Press Enter to close.\n'
    read -r
    exit 0
fi

pick() { # pick <prompt> <option> <detail> [<option> <detail>...]
    local prompt="$1" selection; shift
    # Rows are "option, detail, option"; the option is read from the last column.
    selection="$(printf '%s\t%s\n' "$@" | awk -F '\t' '{ print $1 "\t" $2 "\t" $1 }' |
        "$HOME/.config/hypr/scripts/menu-select" -no-custom -p "$prompt" -display-columns 1 -detail-column 2)" || return 1
    printf '%s\n' "${selection##*$'\t'}"
}

input="${1:-}"

if [[ -z "$input" ]]; then
    # Only search directories that exist. find exits non-zero on a missing
    # starting point, and under `set -e` with pipefail that killed the script
    # the instant the picker returned — which looked like the feature silently
    # doing nothing.
    search_dirs=()
    for directory in "$HOME/Pictures" "$HOME/Videos" "$HOME/Downloads"; do
        [[ -d "$directory" ]] && search_dirs+=("$directory")
    done
    ((${#search_dirs[@]})) || {
        notify-send -u critical -a Transcode 'Nothing to transcode' 'No Pictures, Videos or Downloads directory.'
        exit 1
    }

    # Newest first, the way Omarchy's file picker does it: the clip you just
    # recorded or downloaded is nearly always the one you came here to shrink.
    # Hidden directories are pruned so caches and .git do not flood the list.
    mapfile -t candidates < <(find "${search_dirs[@]}" \
        \( -type d -name '.*' ! -name '.' -prune \) -o -type f ! -name '.*' \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
           -o -iname '*.gif' -o -iname '*.heic' -o -iname '*.avif' \
           -o -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' -o -iname '*.mkv' \
           -o -iname '*.webm' -o -iname '*.avi' \) \
        -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-)

    ((${#candidates[@]})) || {
        notify-send -u critical -a Transcode 'Nothing to transcode' 'No pictures or videos found.'
        exit 1
    }

    # Rows are "name, folder, icon, path": the file name as the title, its
    # folder (relative to home) under it, an image or video icon, and the
    # absolute path in the last column.
    selection="$(printf '%s\n' "${candidates[@]}" | awk -v home="$HOME" '
        {
            slash = match($0, /\/[^\/]*$/)
            folder = substr($0, 1, slash - 1)
            if (index(folder, home) == 1) folder = "~" substr(folder, length(home) + 1)
            kind = tolower($0) ~ /\.(mp4|mov|m4v|mkv|webm|avi)$/ ? "video-x-generic" : "image-x-generic"
            print substr($0, slash + 1) "\t" folder "\t" kind "\t" $0
        }' |
        "$HOME/.config/hypr/scripts/menu-select" -p 'Transcode' -display-columns 1 -detail-column 2 -icon-column 3)" || exit 0
    input="${selection##*$'\t'}"
    [[ -n "$input" && "$input" != "$selection" ]] || exit 0
fi

[[ -f "$input" ]] || exit 0

type="$(media_type "$input")" || {
    notify-send -u critical -a Transcode 'Transcode' "Not a picture or video: $(basename -- "$input")"
    exit 1
}

if [[ "$type" == image ]]; then
    format="$(pick 'Format' jpg 'Smaller files, best for photos' png 'Lossless, best for screenshots')" || exit 0
    [[ -n "$format" ]] || exit 0
    resolution="$(pick 'Size' high 'Up to 3160 px wide' medium 'Up to 2160 px wide' low 'Up to 1080 px wide')" || exit 0
else
    format="$(pick 'Format' mp4 'H.264 video, plays everywhere' gif 'Silent animation at 10 fps')" || exit 0
    [[ -n "$format" ]] || exit 0
    resolution="$(pick 'Resolution' 4k '2160p, encoded as H.265' 1080p 'Full HD' 720p 'HD, smallest files')" || exit 0
fi
[[ -n "$resolution" ]] || exit 0

exec kitty --class dotfiles-transcode --title 'Transcode media' -e "$0" --run "$input" "$format" "$resolution"
