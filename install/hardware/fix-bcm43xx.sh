# Install Wi-Fi drivers for Broadcom chips found in some MacBooks, as well as other systems:
# - BCM4360 (2013–2015 MacBooks)
# - BCM4331 (2012, early 2013 MacBooks)

# This board has no PCI bus and Arch Linux ARM does not pull in pciutils, so lspci is
# both absent and meaningless here. The assignment is at top level under `bash -eE`, so
# unguarded it aborts the whole apply before any later hardware leaf runs.
pci_info=$(lspci -nn 2>/dev/null || true)

if (echo "$pci_info" | grep -q "14e4:43a0" || echo "$pci_info" | grep -q "14e4:4331"); then
  echo "BCM4360 / BCM4331 detected"
  omarchy-pkg-add broadcom-wl dkms linux-headers
fi
