#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

source "$ROOT/install/helpers/packages.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

manifest="$test_tmp/omarchy-base.packages"
overlay_dir="$test_tmp/arch/testarch"
overlay="$overlay_dir/omarchy-base.packages"
mkdir -p "$overlay_dir"

# The canonical parse, from bin/omarchy-upgrade-to-quattro. Kept verbatim rather than
# called through the helper, so the test pins the helper against the parser it claims to
# match instead of against itself.
canonical() {
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$1"
}

cat >"$manifest" <<'EOF'
# a leading comment
alpha
bravo   # a trailing comment

  # an indented comment
charlie
delta
EOF

# With no overlay directory at all, output must equal the canonical parse byte for byte.
# This is the property that lets the helper replace the existing readers on x86_64,
# where no overlay exists, without changing what any of them install.
diff <(OMARCHY_ARCH=testarch resolve_packages "$manifest") <(canonical "$manifest") >/dev/null ||
  fail "resolve_packages with no overlay matches the canonical parse"
pass "resolve_packages with no overlay matches the canonical parse"

# Trailing comments and indented comments are exactly where the two parsers in the tree
# disagreed: the grep pair in bin/omarchy-reinstall-pkgs kept "bravo   # a trailing
# comment" whole and let an indented comment through, because its ^ anchor missed it.
[[ $(OMARCHY_ARCH=testarch resolve_packages "$manifest") == $'alpha\nbravo\ncharlie\ndelta' ]] ||
  fail "resolve_packages strips trailing, indented and whole-line comments"
pass "resolve_packages strips trailing, indented and whole-line comments"

# An architecture with no overlay of its own must behave as though none existed, since
# that is every architecture but the ported one.
[[ $(OMARCHY_ARCH=otherarch resolve_packages "$manifest") == $'alpha\nbravo\ncharlie\ndelta' ]] ||
  fail "resolve_packages ignores an overlay belonging to another architecture"
pass "resolve_packages ignores an overlay belonging to another architecture"

printf '# drop this one\nbravo\n' >"$overlay.exclude"
[[ $(OMARCHY_ARCH=testarch resolve_packages "$manifest") == $'alpha\ncharlie\ndelta' ]] ||
  fail "an exclude overlay removes the package and takes comments"
pass "an exclude overlay removes the package and takes comments"

# Replacement happens in place: a substituted package keeps the position its predecessor
# held, so the output stays diffable against another architecture's.
printf 'charlie charlie-ng\n' >"$overlay.replace"
[[ $(OMARCHY_ARCH=testarch resolve_packages "$manifest") == $'alpha\ncharlie-ng\ndelta' ]] ||
  fail "a replace overlay substitutes in place"
pass "a replace overlay substitutes in place"

printf 'echo\n' >"$overlay.add"
[[ $(OMARCHY_ARCH=testarch resolve_packages "$manifest") == $'alpha\ncharlie-ng\ndelta\necho' ]] ||
  fail "an add overlay appends"
pass "an add overlay appends"

# A stale overlay entry is a silent no-op otherwise, which is how an overlay drifts out
# of step with a manifest that moved under it.
printf 'bravo\nnot-in-the-manifest\n' >"$overlay.exclude"
rm -f "$overlay.replace" "$overlay.add"
warnings=$(OMARCHY_ARCH=testarch resolve_packages "$manifest" 2>&1 >/dev/null)
[[ $warnings == *not-in-the-manifest* ]] ||
  fail "an overlay entry matching nothing warns on stderr"
pass "an overlay entry matching nothing warns on stderr"

[[ $warnings != *bravo* ]] ||
  fail "an overlay entry that did match stays quiet"
pass "an overlay entry that did match stays quiet"

# Warning, not failing: these helpers run under `bash -eE` via run_logged, where a
# non-zero return aborts the whole install. A stale overlay line must not do that.
OMARCHY_ARCH=testarch resolve_packages "$manifest" >/dev/null 2>&1 ||
  fail "a stale overlay entry does not fail the resolver"
pass "a stale overlay entry does not fail the resolver"

# An empty result must be empty, not one blank line, or the caller's array gets a
# zero-length element and pacman is handed an empty argument.
empty="$test_tmp/empty.packages"
printf '# nothing but a comment\n\n' >"$empty"
[[ -z $(OMARCHY_ARCH=testarch resolve_packages "$empty") ]] ||
  fail "a manifest with no packages resolves to nothing"
pass "a manifest with no packages resolves to nothing"

[[ $(OMARCHY_ARCH=testarch resolve_packages "$empty" | wc -l | tr -d ' ') == 0 ]] ||
  fail "a manifest with no packages emits no lines at all"
pass "a manifest with no packages emits no lines at all"

# The shipped overlay must describe the manifest it ships against. A rename upstream
# would otherwise turn an exclusion into a no-op and quietly reinstate the package.
shipped_warnings=$(OMARCHY_ARCH=aarch64 resolve_packages "$ROOT/install/omarchy-base.packages" 2>&1 >/dev/null)
[[ -z $shipped_warnings ]] ||
  fail "every entry in the shipped aarch64 overlay matches the manifest" "$shipped_warnings"
pass "every entry in the shipped aarch64 overlay matches the manifest"
