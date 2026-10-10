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

# The same stream also drives the Waybar bell (custom/notifications, signal
# 11): it refreshes whenever a notification closes or dunstctl changes the
# history or do-not-disturb, instead of polling dunst every few seconds.
refresh_bell() {
    (sleep 0.15; pkill -RTMIN+11 -x waybar 2>/dev/null) &
}

# NotificationClosed is sent only to the app that posted the notification, so
# a plain signal subscription never sees it; dbus-monitor can. dunstctl's
# history and pause commands are method calls on dunst's own interface.
dbus-monitor --session \
    "type='signal',interface='org.freedesktop.Notifications',member='NotificationClosed'" \
    "type='method_call',interface='org.dunstproject.cmd0'" \
    "type='method_call',interface='org.freedesktop.DBus.Properties',member='Set',path='/org/freedesktop/Notifications'" |
while read -r line; do
    case "$line" in
        *member=NotificationClosed*)
            read -r _ id
            read -r _ reason
            [[ "$reason" == 2 ]] && dunstctl history-rm "$id" >/dev/null 2>&1
            refresh_bell
            ;;
        *interface=org.dunstproject.cmd0* | *member=Set*)
            refresh_bell
            ;;
    esac
done
