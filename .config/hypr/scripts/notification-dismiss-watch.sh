#!/usr/bin/env bash
# Delete notifications from dunst's history when they are dismissed by hand.
#
# Dunst has no click action that removes a notification from history, so
# clicking one away only hides it and it lingers in the Waybar bell count.
# Dunst does report why each notification closed: 1 = expired, 2 = dismissed
# by the user. Dismissed ones are deleted here; expired ones stay in history
# so missed notifications can still be recalled from the bell.

set -u

# One watcher per session, even if autostart runs twice.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/notification-dismiss-watch.lock"
flock -n 9 || exit 0

# NotificationClosed is sent only to the app that posted the notification, so
# a plain signal subscription never sees it; dbus-monitor can.
dbus-monitor --session "type='signal',interface='org.freedesktop.Notifications',member='NotificationClosed'" |
while read -r line; do
    [[ "$line" == *member=NotificationClosed* ]] || continue
    read -r _ id
    read -r _ reason
    [[ "$reason" == 2 ]] && dunstctl history-rm "$id" >/dev/null 2>&1
done
