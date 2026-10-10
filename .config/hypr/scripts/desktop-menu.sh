#!/usr/bin/env bash
# The desktop menu (Super+Escape). Its content lives in
# ~/.config/quickshell/panels/menu.json and it is drawn by Menu.qml.
#
# Usage: desktop-menu.sh [route]   e.g. desktop-menu.sh setup
exec "$HOME/.config/hypr/scripts/menu.sh" "${1:-}"
