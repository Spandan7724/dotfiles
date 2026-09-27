#!/usr/bin/env bash
if pgrep -x rofi >/dev/null 2>&1; then pkill -x rofi; else exec rofi -show drun -modi drun -p 'Apps'; fi
