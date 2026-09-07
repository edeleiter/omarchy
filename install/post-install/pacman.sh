# The packaged pacman.conf names a local [omarchy] repository at an unconditional
# file:///var/cache/omarchy-repo. `pacman -Sy` fails outright against a Server whose
# database is missing - and takes omarchy-update, omarchy-pkg-add and
# omarchy-reinstall-pkgs down with it - so guarantee a floor before installing the config
# that depends on it. An empty database is a valid one; if packages are already published
# there, repo-add is not called and nothing is disturbed.
#
# The ._* filter is for AppleDouble droppings: this repo is populated by rsync from a Mac
# (cm5-alarm/scripts/build-pkgs), and repo-add chokes on ._foo.pkg.tar.xz stubs.
omarchy_repo=/var/cache/omarchy-repo
install -d -m 0755 "$omarchy_repo"
find "$omarchy_repo" -name '._*' -delete
if [[ ! -f $omarchy_repo/omarchy.db ]]; then
  (cd "$omarchy_repo" && repo-add --quiet omarchy.db.tar.gz) ||
    echo "Could not initialise the local [omarchy] repository database at $omarchy_repo"
fi

# Configure pacman after package installation completes. Offline target package
# installs use the live ISO's offline pacman.conf until this final restore.
cp -f "$OMARCHY_PATH/default/pacman/pacman-${OMARCHY_MIRROR:-stable}.conf" /etc/pacman.conf
cp -f "$OMARCHY_PATH/default/pacman/mirrorlist-${OMARCHY_MIRROR:-stable}" /etc/pacman.d/mirrorlist

# Wait for CUPS to own the file, the way omarchy-settings does, so pacman does
# not turn the override into a .pacnew during ISO package installation.
if [[ -f $OMARCHY_PATH/etc-overrides/cups-cups-files.conf && -f /etc/cups/cups-files.conf ]]; then
  install -m 0640 -o root -g cups "$OMARCHY_PATH/etc-overrides/cups-cups-files.conf" /etc/cups/cups-files.conf
  rm -f /etc/cups/cups-files.conf.pacnew
fi

source "$OMARCHY_INSTALL/hardware/pacman.sh"
