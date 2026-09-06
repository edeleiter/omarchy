# Enable services only. Installs are followed by reboot, so don't start/reload
# daemons mid-install. UFW and hardware-gated services stay in their own scripts.

# Every enable below was bare. run_logged runs this leaf under `bash -eE` and returns
# its exit code, so a single unit that is not installed aborts the entire apply - and
# on Arch Linux ARM several of these are genuinely absent or optional
# (linux-modules-cleanup comes from kernel-modules-hook; power-profiles-daemon has
# patchy support outside x86 laptops). Attempt-and-warn, mirroring
# enable_system_service in bin/omarchy-upgrade-to-quattro.
enable_system_service() {
  local unit="$1"

  systemctl enable "$unit" >/dev/null 2>&1 ||
    echo "Could not enable $unit; it may not be installed on this system."
}

enable_system_service cups.service
enable_system_service avahi-daemon.service
enable_system_service linux-modules-cleanup.service
enable_system_service docker.socket
enable_system_service systemd-resolved.service
enable_system_service NetworkManager.service
# Don't let network-online.target hold up graphical.target waiting for
# DHCP/Wi-Fi association. Nothing in the session needs to block on the network.
# Mirrors the systemd-networkd-wait-online mask in install/hardware/network.sh.
systemctl mask NetworkManager-wait-online.service
enable_system_service power-profiles-daemon.service
enable_system_service sddm.service
# Kill one runaway app scope instead of letting reclaim thrashing take the
# whole session down. [Install] pulls in systemd-oomd.socket via Also=, which
# is what the user manager reports app.slice candidacy over.
enable_system_service systemd-oomd.service
