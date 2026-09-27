#!/usr/bin/env bash
set -euo pipefail
if ! command -v fprintd-enroll >/dev/null 2>&1; then notify-send 'Fingerprint setup' 'Install fprintd and libfprint first.'; exit 1; fi
printf 'Enroll a fingerprint. Follow the prompts and repeatedly touch the sensor.\n\n'; fprintd-enroll
printf '\nVerify the enrolled fingerprint.\n\n'; fprintd-verify
for pam_file in /etc/pam.d/hyprlock /etc/pam.d/sudo /etc/pam.d/polkit-1; do
    [[ -f "$pam_file" ]] || continue
    if ! grep -q 'pam_fprintd\.so' "$pam_file"; then sudo sed -i '1iauth      sufficient pam_fprintd.so' "$pam_file"; fi
done
printf '\nFingerprint authentication is configured for Hyprlock, sudo, and polkit.\n'
notify-send 'Fingerprint setup complete' 'Fingerprint authentication is ready.'
