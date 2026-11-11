#!/usr/bin/env bash
# System-level setup. Run once as your user (it uses
# sudo); every step is idempotent, so running it again is safe.
#
#   1. Snapper + snap-pac + grub-btrfs: a snapshot pair around every pacman
#      transaction, and a GRUB submenu to boot any snapshot read-only.
#   2. systemd-oomd (the user's app.slice is the kill candidate), zram = RAM.
#   3. NetworkManager-wait-online masked, 5 s stop timeout.
#   4. systemd-resolved as the system resolver.
#   5. Plymouth splash and SDDM in the desktop theme's colours, kept in sync
#      by ~/.config/themes/boot-theme.sh through a NOPASSWD helper.
#   6. udiskie and hyprsunset packages (the session starts them).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM_DIR="$REPO_DIR/system"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

if ((EUID == 0)); then
    printf 'Run this as your user, not root; it calls sudo itself.\n' >&2
    exit 1
fi

sudo -v
# Keep the sudo timestamp fresh for the length of the run.
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
keepalive=$!
trap 'kill "$keepalive" 2>/dev/null || true' EXIT

backup() {
    local file="$1"
    [[ -f "$file" && ! -f "$file.pre-dotfiles" ]] && sudo cp -a -- "$file" "$file.pre-dotfiles"
    return 0
}

# ---- Packages ---------------------------------------------------------------

info "Installing packages..."
sudo pacman -S --needed --noconfirm \
    snapper snap-pac grub-btrfs inotify-tools plymouth udiskie hyprsunset

# ---- 1. Snapshots -----------------------------------------------------------

if [[ "$(findmnt -no FSTYPE /)" == btrfs ]]; then
    info "Configuring Snapper for the root subvolume..."
    if [[ ! -f /etc/snapper/configs/root ]]; then
        if [[ -e /.snapshots ]] && ! sudo btrfs subvolume show /.snapshots >/dev/null 2>&1; then
            warn "/.snapshots exists but is not a subvolume; skipping Snapper."
        else
            [[ -e /.snapshots ]] && sudo btrfs subvolume delete /.snapshots >/dev/null
            sudo snapper -c root create-config /
        fi
    fi
    if [[ -f /etc/snapper/configs/root ]]; then
        sudo install -m 640 "$SYSTEM_DIR/snapper/root" /etc/snapper/configs/root
        sudo systemctl disable --now snapper-timeline.timer >/dev/null 2>&1 || true
        sudo systemctl enable --now snapper-cleanup.timer
        # A first, labelled baseline to fall back to.
        if ! sudo snapper -c root list --columns description 2>/dev/null | grep -q 'dotfiles baseline'; then
            sudo snapper -c root create --type single --cleanup-algorithm number \
                --userdata important=yes --description 'dotfiles baseline'
        fi
    fi

    info "Enabling grub-btrfs (boot snapshots from the GRUB menu)..."
    sudo systemctl enable --now grub-btrfsd.service
else
    warn "Root is not btrfs; skipping Snapper and grub-btrfs."
fi

# ---- 2. OOM handling and zram ----------------------------------------------

info "Enabling systemd-oomd..."
sudo install -Dm644 "$SYSTEM_DIR/systemd/oomd.conf" /etc/systemd/oomd.conf.d/10-dotfiles.conf
sudo systemctl enable --now systemd-oomd.service
sudo systemctl restart systemd-oomd.service

info "Sizing zram to all of RAM (applies at next boot)..."
backup /etc/systemd/zram-generator.conf
sudo install -Dm644 "$SYSTEM_DIR/zram-generator.conf" /etc/systemd/zram-generator.conf

# ---- 3. Boot and shutdown speed --------------------------------------------

info "Masking NetworkManager-wait-online and shortening stop timeouts..."
# Only docker.service and archlinux-keyring-wkd-sync want network-online.target
# here; neither needs to hold boot until the network is fully up.
sudo systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1 || true
sudo systemctl mask NetworkManager-wait-online.service
sudo install -Dm644 "$SYSTEM_DIR/systemd/faster-shutdown.conf" /etc/systemd/system.conf.d/10-faster-shutdown.conf
sudo install -Dm644 "$SYSTEM_DIR/systemd/faster-shutdown.conf" /etc/systemd/user.conf.d/10-faster-shutdown.conf

# ---- 4. systemd-resolved ----------------------------------------------------

info "Switching DNS to systemd-resolved..."
sudo systemctl enable --now systemd-resolved.service
if [[ "$(readlink /etc/resolv.conf 2>/dev/null)" != *stub-resolv.conf ]]; then
    backup /etc/resolv.conf
    sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    # NetworkManager notices the symlink and hands its DNS servers to resolved.
    sudo systemctl restart NetworkManager.service
fi

# ---- 5. Plymouth, initramfs and GRUB ---------------------------------------

info "Adding Plymouth and grub-btrfs-overlayfs to the initramfs..."
backup /etc/mkinitcpio.conf
if ! grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then
    sudo sed -i -E '/^HOOKS=/ s/\b(udev|systemd)\b/& plymouth/' /etc/mkinitcpio.conf
fi
# Lets a read-only snapshot boot with a writable overlay on top.
if ! grep -qE '^HOOKS=.*\bgrub-btrfs-overlayfs\b' /etc/mkinitcpio.conf; then
    sudo sed -i -E '/^HOOKS=/ s/\)\s*$/ grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
fi
grep '^HOOKS=' /etc/mkinitcpio.conf

info "Adding 'splash' to the kernel command line..."
backup /etc/default/grub
if ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=".*\bsplash\b' /etc/default/grub; then
    sudo sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=")([^"]*)"/\1\2 splash"/' /etc/default/grub
fi
grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub

# This machine boots unified kernel images (GRUB's `uki` command loads
# /boot/EFI/Linux/*.efi), and a UKI carries its own command line from
# /etc/kernel/cmdline, so GRUB_CMDLINE_LINUX_DEFAULT never reaches it.
if [[ -f /etc/kernel/cmdline ]]; then
    backup /etc/kernel/cmdline
    for word in loglevel=3 quiet splash; do
        grep -qE "(^|\s)${word}(\s|$)" /etc/kernel/cmdline \
            || sudo sed -i -E "1 s/\s*$/ ${word}/" /etc/kernel/cmdline
    done
    printf 'UKI command line: %s\n' "$(</etc/kernel/cmdline)"
fi

# grub-btrfs boots a snapshot from a plain kernel + initramfs pair; it cannot
# use a UKI. A preset that only builds UKIs leaves the snapshot entries (and
# GRUB's own 10_linux entries) without an initramfs, so build one beside each
# UKI. mkinitcpio produces both when a preset sets both.
for preset in /etc/mkinitcpio.d/*.preset; do
    [[ -f "$preset" ]] || continue
    grep -qE '^default_uki=' "$preset" || continue
    grep -qE '^default_image=' "$preset" && continue
    pkgbase="$(basename "$preset" .preset)"
    backup "$preset"
    sudo sed -i -E "/^default_uki=/i default_image=\"/boot/initramfs-${pkgbase}.img\"" "$preset"
    printf '%s: added default_image=/boot/initramfs-%s.img\n' "$preset" "$pkgbase"
done

info "Installing the login screen and boot splash theme helper..."
sudo install -Dm755 "$SYSTEM_DIR/dotfiles-boot-theme-root" /usr/local/libexec/dotfiles-boot-theme-root
printf '%s\n' "$USER ALL=(root) NOPASSWD: /usr/local/libexec/dotfiles-boot-theme-root *" \
    | sudo tee /etc/sudoers.d/dotfiles-boot-theme >/dev/null
sudo chmod 0440 /etc/sudoers.d/dotfiles-boot-theme
if ! sudo visudo -cf /etc/sudoers.d/dotfiles-boot-theme >/dev/null; then
    sudo rm -f /etc/sudoers.d/dotfiles-boot-theme
    warn "The boot-theme sudo rule was invalid and has been removed."
fi
sudo install -Dm644 "$SYSTEM_DIR/sddm/silent-theme-config.hook" /etc/pacman.d/hooks/sddm-silent-theme-config.hook

# Writes the Plymouth theme and rebuilds the initramfs (picking up the hooks
# above), and writes the SDDM colours and wallpaper.
info "Applying the current desktop theme to Plymouth and SDDM..."
"$HOME/.config/themes/boot-theme.sh" --force --foreground
# boot-theme only rebuilds when the splash colours changed; make sure the new
# hooks are in the image either way.
sudo mkinitcpio -P

if sudo test -f /boot/grub/grub.cfg; then
    info "Regenerating grub.cfg..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
else
    warn "/boot/grub/grub.cfg not found; regenerate your GRUB config by hand."
fi

info "Done. Reboot to pick up the splash, zram size and stop timeouts."
