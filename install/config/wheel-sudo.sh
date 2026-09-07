# Grant the wheel group general sudo.
#
# Omarchy ships only narrow NOPASSWD rules (omarchy-dns, omarchy-theme-set-browser-policy,
# timedatectl set-timezone). The broad grant comes from ISO provisioning, which this board
# does not use: it is installed with `omarchy-apply-system --install-user X` onto an
# existing Arch Linux ARM system, and Arch ships %wheel commented out.
#
# Without this the desktop appears to work and then fails the first time anything needs
# root - omarchy-update dies on `sudo paccache -rk2`, which reads as a packaging problem
# rather than a missing sudoers rule.
#
# A drop-in rather than an edit to /etc/sudoers, validated before install: a syntax error
# in sudoers locks out sudo entirely, and on a headless board that means serial-only.
if [[ -d /etc/sudoers.d ]] && ! sudo -n -l -U "${OMARCHY_INSTALL_USER:-root}" 2>/dev/null | grep -q '(ALL'; then
  tmp="$(mktemp)"
  cat >"$tmp" <<'SUDOERS'
%wheel ALL=(ALL:ALL) ALL
SUDOERS

  if visudo -c -f "$tmp" >/dev/null 2>&1; then
    install -m 440 -o root -g root "$tmp" /etc/sudoers.d/10-wheel
    echo "Granted general sudo to the wheel group"
  else
    echo "Refusing to install an invalid sudoers drop-in" >&2
  fi

  rm -f "$tmp"
fi

true
