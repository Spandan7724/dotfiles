#!/usr/bin/env bash
# Keep the platform and NVIDIA limits in step with the power profile. Waits for
# power-profiles-daemon to announce a change on the system bus instead of
# polling it, so nothing runs between profile switches.

set -uo pipefail
helper=/usr/local/libexec/dotfiles-power-profile-root
bus_name=org.freedesktop.UPower.PowerProfiles
bus_path=/org/freedesktop/UPower/PowerProfiles
command -v busctl >/dev/null 2>&1 || exit 0
command -v gdbus >/dev/null 2>&1 || exit 0
[[ -x "$helper" ]] || exit 0

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/dotfiles-power-profile.lock"
flock -n 9 || exit 0

apply() {
    case "$1" in power-saver | balanced | performance) ;; *) return ;; esac
    # One retry covers a helper that briefly fails right after boot.
    sudo -n "$helper" "$1" >/dev/null 2>&1 || { sleep 5; sudo -n "$helper" "$1" >/dev/null 2>&1; }
}

current() {
    busctl --system get-property "$bus_name" "$bus_path" "$bus_name" ActiveProfile 2>/dev/null |
        sed -n 's/^s "\(.*\)"$/\1/p'
}

last="$(current)"
apply "$last"

# The daemon reports each change on two object paths; act on the first.
gdbus monitor --system --dest "$bus_name" 2>/dev/null |
while IFS= read -r line; do
    [[ "$line" == "$bus_path:"*"'ActiveProfile': <'"* ]] || continue
    profile="${line#*\'ActiveProfile\': <\'}"
    profile="${profile%%\'*}"
    [[ "$profile" != "$last" ]] || continue
    apply "$profile"
    last="$profile"
done

# gdbus only returns if the bus connection is lost; let systemd restart us.
exit 1
