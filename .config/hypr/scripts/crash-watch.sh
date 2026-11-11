#!/usr/bin/env bash
# Announce crashed programs. systemd-coredump journals every core dump under a
# fixed MESSAGE_ID with structured COREDUMP_* fields; follow those and raise a
# notification for this user's crashes, with a "Details" action that opens
# `coredumpctl info` for the dump.
# Run by systemd/user/dotfiles-crash-watch.service.
#
# CRASH_WATCH_IGNORE: extended regex of program names never to announce.

set -uo pipefail

readonly COREDUMP_MESSAGE_ID=fc2e22bc6ee647b6b90729ab34a250b1
# A crash loop dumps core over and over; announce each program once a minute.
readonly DEDUPE_SECONDS=60
readonly IGNORE="${CRASH_WATCH_IGNORE:-}"
terminal="$HOME/.config/hypr/scripts/default-launcher.sh"

declare -A last_notified

announce() {
    local name="$1" pid="$2" signal="$3" action
    action="$(notify-send --app-name=crash-watch --urgency=critical \
        --icon=dialog-error --action=details=Details \
        "$name crashed" "Killed by ${signal}. Core dump saved (PID $pid)." 2>/dev/null)"
    if [[ "$action" == details ]]; then
        # PID is checked numeric by the caller, so it is safe in the command.
        setsid uwsm-app -- "$terminal" terminal -e sh -c \
            "coredumpctl info $pid; printf '\nPress Enter to close'; read -r _" >/dev/null 2>&1 &
    fi
}

journalctl --follow --lines=0 --output=json "MESSAGE_ID=$COREDUMP_MESSAGE_ID" 2>/dev/null |
    while IFS= read -r entry; do
        # A dash for missing or empty fields, so a blank one cannot shift the rest.
        IFS=$'\t' read -r uid comm pid exe signal < <(
            jq -r 'def f: if . == null or . == "" then "-" else . end;
                   [(.COREDUMP_UID // ._UID | f), (.COREDUMP_COMM | f), (.COREDUMP_PID | f),
                    (.COREDUMP_EXE | f), (.COREDUMP_SIGNAL_NAME | f)] | @tsv' <<<"$entry" 2>/dev/null
        )
        [[ "${pid:-}" =~ ^[0-9]+$ && "${uid:-}" =~ ^[0-9]+$ ]] || continue
        ((uid == UID)) || continue

        # comm is cut at 15 characters; the executable's name is better.
        name="$comm"
        [[ "$exe" == /* ]] && name="${exe##*/}"
        [[ -n "$name" && "$name" != - ]] || name=unknown
        [[ -n "$IGNORE" && "$name" =~ $IGNORE ]] && continue

        now="$EPOCHSECONDS"
        ((now - ${last_notified[$name]:-0} < DEDUPE_SECONDS)) && continue
        last_notified[$name]="$now"
        # Backgrounded so a notification waiting on its action never blocks
        # the next crash.
        announce "$name" "$pid" "$signal" &
    done
