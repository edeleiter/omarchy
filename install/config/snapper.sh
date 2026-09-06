SNAPPER_CONFIG_PATH="${OMARCHY_SNAPPER_CONFIG_PATH:-/etc/snapper/configs/root}"
SNAPPER_CONF_PATH="${OMARCHY_SNAPPER_CONF_PATH:-/etc/conf.d/snapper}"
template="${OMARCHY_SNAPPER_TEMPLATE:-${OMARCHY_PATH:-/usr/share/omarchy}/default/snapper/root}"

echo "Configuring Omarchy Snapper snapshot retention"

if [[ ! -f $SNAPPER_CONFIG_PATH ]]; then
  mkdir -p "$(dirname "$SNAPPER_CONFIG_PATH")"

  if [[ ${OMARCHY_SNAPPER_CONFIGURE_TEST:-0} == "1" ]]; then
    : >"$SNAPPER_CONFIG_PATH"
  else
    # snapper manages btrfs subvolumes, so create-config cannot succeed on an ext4
    # root - and this board's root is ext4 by design. run_logged runs this leaf under
    # `bash -eE` and returns its status, so without the guard both attempts failing
    # aborts the entire apply. The retention config written below is still installed;
    # it simply has no snapper config to sit beside, which is the intended outcome.
    snapper --no-dbus -c root create-config / >/dev/null 2>&1 ||
      snapper -c root create-config / >/dev/null 2>&1 || true
  fi
fi

install -m 0644 "$template" "$SNAPPER_CONFIG_PATH"

mkdir -p "$(dirname "$SNAPPER_CONF_PATH")"
printf '%s\n' 'SNAPPER_CONFIGS="root"' >"$SNAPPER_CONF_PATH"
chmod 0644 "$SNAPPER_CONF_PATH"

systemctl disable --now snapper-timeline.timer >/dev/null 2>&1 || true
systemctl enable --now snapper-cleanup.timer limine-snapper-sync.service >/dev/null 2>&1 || true
