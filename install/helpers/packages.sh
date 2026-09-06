# Read a .packages manifest, applying this architecture's overlay if one exists.
#
# The canonical parse is the sed from bin/omarchy-upgrade-to-quattro, which
# test/shell.d/preinstalls-test.sh uses too: strip trailing comments, then drop blank
# lines. It is deliberately the only parse in the tree - the older variant in
# bin/omarchy-reinstall-pkgs kept trailing comments and its ^ anchors missed leading
# whitespace, so the two disagreed on the same file.
#
# Overlays sit beside the manifest, under arch/<arch>/ named for the manifest:
#
#   install/arch/aarch64/omarchy-base.packages.exclude   one package per line, removed
#   install/arch/aarch64/omarchy-base.packages.replace   "old new" pairs, substituted
#   install/arch/aarch64/omarchy-base.packages.add       one package per line, appended
#
# Overlay files are parsed the same way, so they take comments too. A missing overlay
# file is not an error: on x86_64 there are none, and the output is then byte-identical
# to the bare canonical parse. That identity is what the tests pin down.
#
# Order is preserved throughout. pacman does not care, but a stable order is what makes
# the byte-identity check meaningful and diffs between architectures readable.

packages_strip_comments() {
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$@"
}

# Both overlay passes below report entries that matched nothing. An overlay entry that
# matches nothing is a silent no-op, and silent no-ops are how an overlay rots: upstream
# renames a package, the exclude keeps "working", and nobody learns the manifest moved.
#
# It warns rather than fails on purpose. These helpers run under `bash -eE` via
# run_logged, where a non-zero return aborts the entire apply - a stale overlay line is
# not worth an aborted install.

# OMARCHY_ARCH exists so the tests can exercise an overlay for an architecture they are
# not running on, and so a cross-architecture resolve can be inspected by hand. It is not
# set anywhere at runtime: uname decides. Note macOS reports arm64 where Linux reports
# aarch64, so a checkout on a Mac resolves no overlay at all - which is what makes the
# byte-identity check meaningful there.
resolve_packages() {
  local listfile="$1"
  local arch="${OMARCHY_ARCH:-$(uname -m)}"
  local overlay packages added

  overlay="$(dirname -- "$listfile")/arch/$arch/$(basename -- "$listfile")"
  packages="$(packages_strip_comments "$listfile")"

  if [[ -f $overlay.exclude ]]; then
    packages="$(awk -v kind=exclude '
      NR == FNR { drop[$1] = 1; next }
      $1 in drop { used[$1] = 1; next }
      { print }
      END {
        for (package in drop)
          if (!(package in used))
            printf "resolve_packages: %s overlay lists %s, which the manifest does not contain\n", kind, package >"/dev/stderr"
      }
    ' <(packages_strip_comments "$overlay.exclude") <(printf '%s\n' "$packages"))"
  fi

  if [[ -f $overlay.replace ]]; then
    packages="$(awk -v kind=replace '
      NR == FNR { replacement[$1] = $2; next }
      $1 in replacement { used[$1] = 1; print replacement[$1]; next }
      { print }
      END {
        for (package in replacement)
          if (!(package in used))
            printf "resolve_packages: %s overlay lists %s, which the manifest does not contain\n", kind, package >"/dev/stderr"
      }
    ' <(packages_strip_comments "$overlay.replace") <(printf '%s\n' "$packages"))"
  fi

  if [[ -f $overlay.add ]]; then
    added="$(packages_strip_comments "$overlay.add")"

    if [[ -n $added ]]; then
      packages="$(printf '%s\n%s' "$packages" "$added")"
    fi
  fi

  # A manifest that parses to nothing must emit nothing, not a single blank line.
  if [[ -n $packages ]]; then
    printf '%s\n' "$packages"
  fi
}
