#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/rbac-check.sh"
info() { printf '[INFO] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; return 1; }
MOCK_RBAC_OUTPUT=yes
MOCK_RBAC_CODE=0
ks() {
  [[ "$1" == auth && "$2" == can-i ]] || return 127
  printf '%s\n' "$MOCK_RBAC_OUTPUT"
  return "$MOCK_RBAC_CODE"
}
MOCK_RBAC_OUTPUT=yes; MOCK_RBAC_CODE=0
rbac_expect yes 'allowed named ConfigMap' get configmaps/flask-config --as=mock
MOCK_RBAC_OUTPUT=no; MOCK_RBAC_CODE=1
rbac_expect no 'expected denied ConfigMap' get configmaps/unrelated-config --as=mock
rbac_expect no 'expected denied listing' list configmaps --as=mock
rbac_expect no 'expected denied Secret' get secrets --as=mock
printf 'PASS: expected-denial exit code 1 is handled without aborting.\n'
MOCK_RBAC_OUTPUT='error: connection refused'; MOCK_RBAC_CODE=1
if rbac_expect no 'API failure must NOT count as denial' get secrets --as=mock >/dev/null 2>&1; then
  printf 'FAIL: API error counted as legitimate denial\n' >&2; exit 1
fi
MOCK_RBAC_OUTPUT=no; MOCK_RBAC_CODE=2
if rbac_expect no 'unexpected exit code must fail' get secrets --as=mock >/dev/null 2>&1; then
  printf 'FAIL: unexpected exit code accepted\n' >&2; exit 1
fi
MOCK_RBAC_OUTPUT=yes; MOCK_RBAC_CODE=0
if rbac_expect no 'unexpected allowed access must fail' get secrets --as=mock >/dev/null 2>&1; then
  printf 'FAIL: forbidden permission was accepted\n' >&2; exit 1
fi
MOCK_RBAC_OUTPUT=no; MOCK_RBAC_CODE=1
if rbac_expect yes 'unexpected denied permission must fail' get configmaps/flask-config --as=mock >/dev/null 2>&1; then
  printf 'FAIL: missing required permission was accepted\n' >&2; exit 1
fi
printf 'RBAC REGRESSION TESTS: 8 PASSED (four allowed/denied decisions and four failure controls)\n'
