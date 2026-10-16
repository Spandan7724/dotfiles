#!/usr/bin/env bash

set -euo pipefail

# Rows are "name, folder, icon, path": the file name as the title, its folder
# under it, a file-type icon from the icon theme, and the path relative to
# home in the last column, which is what gets opened. Typed text that matches
# no row is opened as a path relative to home.
selection="$(find "$HOME" \
    -path "$HOME/.cache" -prune -o \
    -path "$HOME/.local/share/Trash" -prune -o \
    -path "$HOME/.git" -prune -o \
    -type f -printf '%P\n' 2>/dev/null | awk '
    BEGIN {
        split("png jpg jpeg gif webp avif heic svg bmp tiff ico", a); for (i in a) icon[a[i]] = "image-x-generic"
        split("mp4 mkv webm mov avi m4v", a); for (i in a) icon[a[i]] = "video-x-generic"
        split("mp3 flac ogg opus wav m4a aac", a); for (i in a) icon[a[i]] = "audio-x-generic"
        split("zip tar gz xz zst bz2 7z rar tgz", a); for (i in a) icon[a[i]] = "package-x-generic"
        split("ttf otf woff woff2", a); for (i in a) icon[a[i]] = "font-x-generic"
        split("sh bash zsh fish", a); for (i in a) icon[a[i]] = "application-x-shellscript"
        split("c h cpp hpp cc", a); for (i in a) icon[a[i]] = "text-x-csrc"
        split("js mjs cjs ts tsx jsx", a); for (i in a) icon[a[i]] = "text-x-javascript"
        split("doc docx odt rtf", a); for (i in a) icon[a[i]] = "x-office-document"
        split("xls xlsx ods csv", a); for (i in a) icon[a[i]] = "x-office-spreadsheet"
        split("ppt pptx odp", a); for (i in a) icon[a[i]] = "x-office-presentation"
        split("html htm", a); for (i in a) icon[a[i]] = "text-html"
        split("md markdown", a); for (i in a) icon[a[i]] = "text-markdown"
        icon["pdf"] = "application-pdf"; icon["epub"] = "application-epub+zip"
        icon["py"] = "text-x-python"; icon["rs"] = "text-rust"; icon["go"] = "text-x-go"
        icon["lua"] = "text-x-lua"; icon["java"] = "text-x-java"; icon["css"] = "text-css"
        icon["json"] = "application-json"; icon["xml"] = "application-xml"; icon["log"] = "text-x-log"
        icon["tex"] = "text-x-tex"; icon["patch"] = "text-x-patch"; icon["diff"] = "text-x-patch"
        icon["desktop"] = "application-x-desktop"; icon["db"] = "application-x-sqlite3"
        icon["sqlite"] = "application-x-sqlite3"; icon["torrent"] = "application-x-bittorrent"
    }
    {
        slash = match($0, /\/[^\/]*$/)
        name = slash ? substr($0, slash + 1) : $0
        folder = slash ? "~/" substr($0, 1, slash - 1) : "~"
        dot = match(name, /\.[^.]+$/)
        ext = dot > 1 ? tolower(substr(name, dot + 1)) : ""
        print name "\t" folder "\t" (ext in icon ? icon[ext] : "text-x-generic") "\t" $0
    }' |
    "$HOME/.config/hypr/scripts/menu-select" -p 'Find files' -placeholder 'Type part of a file name…' -width 760 -lines 12 \
        -display-columns 1 -detail-column 2 -icon-column 3)" || exit 0

[[ "$selection" == *$'\t'* ]] && selection="${selection##*$'\t'}"
[[ -n "$selection" ]] || exit 0
xdg-open "$HOME/$selection" >/dev/null 2>&1 &
