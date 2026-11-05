#!/usr/bin/env bash
# Chapter 7 RBAC helper. A kubectl auth can-i denial prints "no" AND returns
# exit code 1, which must not trip set -e before we evaluate the result.
rbac_expect() {
  local expected="$1" description="$2" result exit_code
  shift 2
  if result="$(ks auth can-i "$@" 2>&1)"; then
    exit_code=0
  else
    exit_code=$?
  fi
  if [[ "$expected" == yes && "$result" == yes && "$exit_code" -eq 0 ]]; then
    info "RBAC PASS: allowed $description (kubectl exit 0)"
    return 0
  fi
  if [[ "$expected" == no && "$result" == no && "$exit_code" -eq 1 ]]; then
    info "RBAC PASS: denied $description as expected (kubectl exit 1)"
    return 0
  fi
  fail "RBAC check for $description expected [$expected], observed [$result] with kubectl exit $exit_code"
}
