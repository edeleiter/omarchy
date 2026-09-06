# The CM5 module carries no Bluetooth radio. Enabling the unit on a machine with no
# adapter leaves a service that fails on every boot, and on a system where the package
# is absent entirely `systemctl enable` returns non-zero and aborts the apply.
if [[ -d /sys/class/bluetooth ]] && compgen -G "/sys/class/bluetooth/*" >/dev/null; then
  systemctl enable bluetooth.service
else
  echo "No Bluetooth adapter present; skipping bluetooth.service"
fi

# AutoEnable stays at its stock default on purpose. It was set to false here to
# persist the power state, which it never did: BlueZ has no such behaviour, so
# all it bought was Bluetooth coming up off on every boot. omarchy-bluetooth-power
# holds the state in the rfkill soft block instead, and leaving AutoEnable alone
# is what lets bluetoothd bring the adapter back up when that block is lifted.
