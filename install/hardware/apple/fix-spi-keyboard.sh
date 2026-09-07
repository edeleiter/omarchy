# Detect MacBook models that need SPI keyboard modules
# 2>/dev/null silences the message, not the exit status. This board has no DMI at all, so
# cat fails, and under `bash -eE` (how run_logged sources every leaf) a failed command
# substitution in an assignment aborts the script before the match below is even reached.
# Same pattern as the lspci guard in install/hardware/fix-bcm43xx.sh.
product_name="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
if [[ $product_name =~ MacBook[89],1|MacBook1[02],1|MacBookPro13,[123]|MacBookPro14,[123] ]]; then
  echo "Detected MacBook with SPI keyboard"

  omarchy-pkg-add macbook12-spi-driver-dkms
  sudo mkdir -p /etc/mkinitcpio.conf.d
  if [[ $product_name == "MacBook8,1" ]]; then
    echo "MODULES=(applespi spi_pxa2xx_platform spi_pxa2xx_pci)" | \
      sudo tee /etc/mkinitcpio.conf.d/macbook_spi_modules.conf >/dev/null
  else
    echo "MODULES=(applespi intel_lpss_pci spi_pxa2xx_platform)" | \
      sudo tee /etc/mkinitcpio.conf.d/macbook_spi_modules.conf >/dev/null
  fi
fi

