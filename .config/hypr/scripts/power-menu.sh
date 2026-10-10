#!/usr/bin/env bash
# Session screen (quickshell/panels/SessionScreen.qml): lock, suspend, log out,
# restart, and shut down. Shared by Super+`, the menu, and Waybar.
exec "$HOME/.config/hypr/scripts/panel.sh" session
