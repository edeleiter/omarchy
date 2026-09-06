# Write the SDDM autologin drop-in ourselves.
#
# Upstream never configures autologin on this path. The only writer is
# bin/omarchy-provision-owner, and its unit
# (install/provisioning/omarchy-provision-owner.service) is enabled by the ISO builder -
# nothing under install/ enables it. install/login/sddm.sh says as much in its own
# comment: "The ISO owns autologin/session state because it knows whether the target is
# encrypted." So a system brought up with `omarchy-apply-system` lands at an SDDM
# password prompt with no autologin configured at all.
#
# On a headless-first bring-up board that prompt is a lockout. Autologin is permanent
# here, and the one-shot cleanup unit that omarchy-provision-owner installs for
# unencrypted targets is deliberately NOT installed: this root is unencrypted ext4 by
# design, so there is no LUKS prompt acting as the auth boundary, and the board is
# single-user. Dropping the autologin on the second boot would only reinstate the
# lockout it was meant to avoid.

if [[ -z ${OMARCHY_INSTALL_USER:-} ]]; then
  echo "OMARCHY_INSTALL_USER is not set; skipping SDDM autologin"
else
  mkdir -p /etc/sddm.conf.d
  printf '[Autologin]\nUser=%s\nSession=omarchy.desktop\n' "$OMARCHY_INSTALL_USER" >/etc/sddm.conf.d/autologin.conf
  chmod 0644 /etc/sddm.conf.d/autologin.conf

  # Matches what omarchy-provision-owner records, so SDDM preselects the session even
  # if the drop-in is later removed by hand.
  mkdir -p /var/lib/sddm
  printf '[Last]\nSession=omarchy.desktop\nUser=%s\n' "$OMARCHY_INSTALL_USER" >/var/lib/sddm/state.conf
  chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true

  echo "SDDM will autologin as $OMARCHY_INSTALL_USER"
fi
