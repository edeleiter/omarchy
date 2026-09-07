#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

# `pacman -S <name>` resolves to the FIRST repository in pacman.conf that carries the name.
# It does not compare versions across repositories and pick the newest. That single fact is
# what this whole file exists to protect.
#
# Arch Linux ARM ships its own hyprland and hyprtoolkit linked against libaquamarine.so=13-64
# while its aquamarine provides 14-64, so ALARM's copies are uninstallable. We rebuild those
# packages against what ALARM actually ships and serve them from a local [omarchy] repo. If
# [omarchy] is listed AFTER [core]/[extra]/[alarm], pacman silently picks ALARM's broken
# copies instead, the dependency resolution fails, and the desktop stops existing.
#
# The ordering is load-bearing, invisible, and easy to undo: a rebase, a merge, or anyone
# tidying the file "so the local repo comes last, like an override" reintroduces it. It had
# no test until now, and both review passes over this port independently flagged that as the
# least defensible thing in the tree.

repo_order() {
  grep -n '^\[' "$1" | sed 's/:\[/ /' | awk '{ print $2 }' | tr -d '[]'
}

configs=("$ROOT"/default/pacman/pacman-*.conf)
(("${#configs[@]}" > 0)) || fail "there is at least one packaged pacman.conf"

for config in "${configs[@]}"; do
  name="$(basename "$config")"

  grep -q '^\[omarchy\]' "$config" ||
    fail "$name declares the [omarchy] repository"

  omarchy_line="$(grep -n '^\[omarchy\]' "$config" | head -1 | cut -d: -f1)"

  # Every other repository must come after it. Checked against all of them rather than just
  # [core], because [extra], [alarm] and [aur] carry the conflicting packages too.
  while read -r line repo; do
    [[ $repo == "[omarchy]" || $repo == "[options]" ]] && continue
    ((omarchy_line < line)) ||
      fail "$name lists [omarchy] before $repo" \
        "[omarchy] is on line $omarchy_line, $repo on line $line.
pacman takes the first repo carrying a name, so a later [omarchy] is ignored entirely."
  done < <(grep -n '^\[' "$config" | tr ':' ' ')
done
pass "[omarchy] precedes every other repository in all packaged pacman configs"

# The local repo is served over file://, and pacman -Sy fails outright against a Server whose
# database is missing - taking omarchy-update, omarchy-pkg-add and omarchy-reinstall-pkgs
# with it. The path is unconditional, so nothing degrades gracefully if the repo is absent.
for config in "${configs[@]}"; do
  name="$(basename "$config")"
  grep -A3 '^\[omarchy\]' "$config" | grep -q '^Server = file://' ||
    fail "$name serves [omarchy] from a local file:// path"
done
pass "[omarchy] is served from a local file:// repository in all packaged pacman configs"

# Unsigned by design: we build these packages ourselves and do not run a signing key for
# them. That is a deliberate decision and should change deliberately, not by drift.
for config in "${configs[@]}"; do
  name="$(basename "$config")"
  grep -A3 '^\[omarchy\]' "$config" | grep -q '^SigLevel = Optional TrustAll' ||
    fail "$name marks the local [omarchy] repo as unsigned-but-trusted"
done
pass "[omarchy] is declared unsigned in all packaged pacman configs"

# [multilib] is x86_64-only. It does not exist on Arch Linux ARM, and pacman errors on a
# repository whose mirrorlist resolves to nothing.
for config in "${configs[@]}"; do
  name="$(basename "$config")"
  if grep -q '^\[multilib\]' "$config"; then
    fail "$name does not enable [multilib]" "[multilib] has no aarch64 counterpart."
  fi
done
pass "no packaged pacman config enables [multilib]"
