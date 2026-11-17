#!/usr/bin/env bash
# Checks the changes made by tests/install.sh. Runs after the install (cache miss) and after a
# restore on a fresh machine (cache hit), so both paths must leave the same system behind.
set -euo pipefail

if [[ "$(id -u)" == 0 ]]; then sudo() { "$@"; }; fi

failures=0
check() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "ok   - ${description}"
  else
    echo "FAIL - ${description}"
    failures=$((failures + 1))
  fi
}

check "the package runs" /usr/games/cowsay hello
check "dpkg knows the package is installed" sh -c "dpkg-query -W -f='\${Status}' cowsay | grep -q 'install ok installed'"
check "the system user exists" id can-test
check "the secret keeps its owner" test "$(sudo stat -c '%U' /opt/can-test/secret)" = can-test
check "the secret keeps mode 600" test "$(sudo stat -c '%a' /opt/can-test/secret)" = 600
check "the secret keeps its content" test "$(sudo cat /opt/can-test/secret)" = secret
check "the setuid bit is kept" test "$(stat -c '%a' /opt/can-test/tool)" = 4755
check "the symbolic link works" test "$(can-test-tool)" = can-test-ok
check "the empty directory exists" test -d /opt/can-test/empty
check "the changed file keeps the change" grep -qx '# can-test' /etc/environment
check "the change is not duplicated" test "$(grep -cx '# can-test' /etc/environment)" = 1

# After a restore on a fresh machine, excluded paths and the workspace must not come back.
if [[ -e "${RUNNER_TEMP:-/nonexistent}/post-restore-ran" ]]; then
  check "the excluded path is not restored" test ! -e /opt/excluded/file
  check "the workspace is not restored" test ! -e can-test-workspace-file
fi

if [[ "${failures}" -gt 0 ]]; then
  echo "::error::${failures} check(s) failed"
  exit 1
fi
