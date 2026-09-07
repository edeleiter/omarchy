#!/bin/bash

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"

stub_dir=$(mktemp -d)
trap 'rm -rf "$stub_dir"' EXIT

cat >"$stub_dir/ufw" <<'STUB'
#!/bin/bash
printf 'ufw %s\n' "$*" >>"$TEST_LOG"
if [[ ${1:-} == status ]]; then
  echo 'Status: inactive'
fi
STUB

cat >"$stub_dir/ufw-docker" <<'STUB'
#!/bin/bash
set -euo pipefail
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/snap/bin/"
printf 'ufw-docker %s\n' "$*" >>"$TEST_LOG"
if ! ufw status 2>/dev/null | grep -Fq 'Status: active'; then
  echo 'inactive' >&2
  exit 1
fi
STUB

cat >"$stub_dir/sed" <<'STUB'
#!/bin/bash
printf 'sed %s\n' "$*" >>"$TEST_LOG"
if [[ ${1:-} == 0,/^PATH=* ]]; then
  exec /usr/bin/sed "$@"
fi
exit 0
STUB

cat >"$stub_dir/systemctl" <<'STUB'
#!/bin/bash
printf 'systemctl %s\n' "$*" >>"$TEST_LOG"
STUB

chmod +x "$stub_dir"/*

export TEST_LOG="$stub_dir/firewall.log"
PATH="$stub_dir:$PATH" bash -eE -c 'source "$1"' bash "$ROOT/install/config/firewall.sh"

grep -q '^ufw-docker install$' "$TEST_LOG" || fail "ufw-docker rules are installed"
grep -q '^systemctl enable ufw$' "$TEST_LOG" || fail "ufw is enabled for next boot"

# `limit`, not `allow`. This board is reachable over ssh permanently and autologs in, so the
# rate limiting is the point; and bin/omarchy-remove-security-sshd deletes a `limit` rule,
# so an `allow` here would make the user-facing "remove SSH access" action silently
# ineffective while reporting success. Matches the acceptance assertion at
# test/acceptance.d/security-test.sh:93 (`^22/tcp\s+LIMIT`).
grep -q '^ufw limit 22/tcp ' "$TEST_LOG" ||
  fail "the SSH port is rate limited rather than plainly allowed" "$(cat "$TEST_LOG")"
# `if`, not `grep … && fail`: under set -e a non-matching grep makes that AND-list return
# non-zero and kills the script on the passing path.
if grep -q '^ufw allow 22/tcp' "$TEST_LOG"; then
  fail "the SSH port must not be opened with a plain allow rule" "$(cat "$TEST_LOG")"
fi

pass "firewall config installs ufw-docker rules without activating live UFW"
