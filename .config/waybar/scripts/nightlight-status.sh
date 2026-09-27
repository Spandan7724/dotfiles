#!/usr/bin/env bash

set -u

if pgrep -x gammastep >/dev/null; then
    printf '{"text":"󰖔","tooltip":"Night light enabled","class":"enabled"}\n'
else
    printf '{"text":"󰖨","tooltip":"Night light disabled","class":"disabled"}\n'
fi
