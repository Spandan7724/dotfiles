#!/usr/bin/env bash

set -euo pipefail

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
themes_root="$config_root/themes"
theme="monochrome-dark"

if [[ -L "$themes_root/current" ]]; then
    theme="$(basename "$(readlink "$themes_root/current")")"
fi

exec "$themes_root/apply.sh" "$theme"
