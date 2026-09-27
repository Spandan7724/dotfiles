#!/usr/bin/env bash
#
# Reboot straight into Windows for one boot, as if Windows Boot Manager had
# been picked from the F12 menu. The next ordinary reboot comes back to Arch.
# The privileged half lives in /usr/local/libexec/dotfiles-reboot-windows-root.

set -uo pipefail
helper=/usr/local/libexec/dotfiles-reboot-windows-root

fail() {
    printf '%s\n' "$1" >&2
    notify-send -u critical 'Reboot to Windows failed' "$1" 2>/dev/null
    exit 1
}

[[ -x "$helper" ]] || fail "$helper is not installed. Run install.sh from the dotfiles."

# sudo -n uses the installer's NOPASSWD rule; pkexec is the fallback prompt.
if ! entry="$(sudo -n "$helper" set 2>/dev/null)"; then
    entry="$(pkexec "$helper" set)" || fail 'Could not set UEFI BootNext to Windows Boot Manager.'
fi

if ! systemctl reboot; then
    # Leave nothing armed behind, or some later reboot would land in Windows.
    sudo -n "$helper" clear 2>/dev/null || pkexec "$helper" clear
    fail "BootNext $entry was set but the reboot was refused, so it has been cleared again."
fi
