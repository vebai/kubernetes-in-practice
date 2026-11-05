#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=04
source "$(dirname "$0")/lib.sh"

# Only the explicitly owned lab Service is changed. If a controlled failure
# interrupts this script, restore the selector before returning to the user.
SERVICE_SELECTOR_FAULT_ACTIVE=0
restore_flask_service_selector() {
  assert_safe_object "$PROFILE" default service/flask-app || return 1
  k patch service/flask-app --type=json -p '[{"op":"replace","path":"/spec/selector","value":{"app.kubernetes.io/name":"flask-app"}}]' || return 1
  k apply -f manifests/chapter-04/flask-service.yaml || return 1
  SERVICE_SELECTOR_FAULT_ACTIVE=0
}
ch04_on_exit() {
  local rc="$1"
  if [[ "$SERVICE_SELECTOR_FAULT_ACTIVE" == 1 ]]; then
    info 'Automatic recovery: restoring lab Service selector after interrupted fault test'
    if restore_flask_service_selector; then
      info 'Service selector restored; rerun Chapter 04 to verify end-to-end recovery'
    else
      info 'WARNING: could not restore Service selector; use the recovery commands in validation/README.md'
    fi
  fi
  finish "$rc"
}
trap 'ch04_on_exit "$?"' EXIT

ensure_local_cluster
k get deployment/flask-app >/dev/null || { fail 'Run Chapter 03 first'; exit 1; }
step 'Restore canonical selector from any interrupted prior lab and verify ready Service backends'
apply_owned "$PROFILE" default service/flask-app manifests/chapter-04/flask-service.yaml
restore_flask_service_selector
check_service_ready
k get service/flask-app -o wide
k get endpointslices -l kubernetes.io/service-name=flask-app -o wide

step 'Verify Pod HTTP locally, then DNS resolves to the exact Service ClusterIP'
assert_contains "$(app_get 'http://127.0.0.1:5000/healthz')" 'alive'
service_ip="$(k get svc/flask-app -o jsonpath='{.spec.clusterIP}')"
resolved_ip="$(k exec deployment/flask-app -- python -c 'import socket;print(socket.gethostbyname("flask-app.default.svc.cluster.local"))')"
assert_eq "$resolved_ip" "$service_ip"
info "Service DNS correctly resolves to $service_ip"
step 'Verify end-to-end Service HTTP, allowing time for data-plane programming'
wait_service_http 'http://flask-app.default.svc.cluster.local/healthz' alive 45

if [[ "$FAULTS" == 1 ]]; then
  step 'Controlled fault: deliberately change Service selector'
  SERVICE_SELECTOR_FAULT_ACTIVE=1
  k patch service/flask-app --type=merge -p '{"spec":{"selector":{"validation-missing-selector":"true"}}}'
  k get svc/flask-app -o json | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["spec"]["selector"].get("validation-missing-selector")=="true", "fault selector not installed"'
  check_service_empty
  k get endpointslices -l kubernetes.io/service-name=flask-app -o wide

  step 'Verify the missing backends actually prevent Service HTTP traffic'
  denied=0
  for ((attempt=1; attempt<=30; attempt++)); do
    if ! app_get 'http://flask-app.default.svc.cluster.local/healthz' >/dev/null 2>&1; then
      info "Expected Service HTTP failure observed on attempt $attempt/30"
      denied=1
      break
    fi
    sleep 2
  done
  [[ "$denied" == 1 ]] || { fail 'Service remained accessible despite zero ready backends'; exit 1; }

  step 'Restore exact Service selector and repeat end-to-end HTTP'
  restore_flask_service_selector
  check_service_ready
  wait_service_http 'http://flask-app.default.svc.cluster.local/healthz' alive 45
fi
summary
