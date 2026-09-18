#!/usr/bin/env bash

set -euo pipefail

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
exec "$config_root/themes/wallpaper.sh" "$1"
