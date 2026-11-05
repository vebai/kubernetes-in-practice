#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=06
source "$(dirname "$0")/lib.sh"
ensure_local_cluster
k get service/flask-app >/dev/null || { fail 'Run Chapter 04 first'; exit 1; }
build_and_load v2.2.0 flask-app/versions/v2.2.0
step 'Apply version 2.2.0 with startup, readiness, liveness and resources'
recover_canonical_configmap_owner "$PROFILE" default manifests/chapter-06/flask-config.yaml
apply_owned "$PROFILE" default configmap/flask-config manifests/chapter-06/flask-config.yaml
apply_owned "$PROFILE" default deployment/flask-app manifests/chapter-06/flask-deployment.yaml
wait_rollout
assert_app_value version v2.2.0
assert_contains "$(app_get 'http://127.0.0.1:5000/readyz')" 'ready'
k get pods -l app.kubernetes.io/name=flask-app -o wide
step 'Enable Metrics Server in isolated profile and wait for usable metrics'
mk addons enable metrics-server
metrics_ready=0
for _ in $(seq 1 45); do
  if k top pods -l app.kubernetes.io/name=flask-app >/dev/null 2>&1; then metrics_ready=1; break; fi
  sleep 4
done
[[ "$metrics_ready" == 1 ]] || { fail 'Metrics Server never returned Pod CPU metrics'; exit 1; }
k top pods -l app.kubernetes.io/name=flask-app
step 'Create CPU HPA and verify current metrics and ScalingActive'
apply_owned "$PROFILE" default hpa/flask-app manifests/chapter-06/hpa.yaml
hpa_active=0
for _ in $(seq 1 45); do
  if k get hpa/flask-app -o json | python3 -c 'import json,sys; d=json.load(sys.stdin); s=d.get("status",{}); cs=s.get("conditions",[]); assert s.get("currentMetrics") and any(c.get("type")=="ScalingActive" and c.get("status")=="True" for c in cs)' 2>/dev/null; then
    hpa_active=1; break
  fi
  sleep 4
done
[[ "$hpa_active" == 1 ]] || { fail 'HPA has no valid metrics or ScalingActive condition'; exit 1; }
k get hpa/flask-app
if [[ "${K8S_HPA_LOAD:-0}" == 1 ]]; then
  step 'Optional controlled CPU load: prove HPA increases desired replicas'
  # This is a bounded, disposable load exercise inside the dedicated local workload.
  k exec deployment/flask-app -- python -c '
import time,urllib.request
end=time.monotonic()+100
while time.monotonic()<end:
 try: urllib.request.urlopen("http://127.0.0.1:5000/work", timeout=30).read()
 except Exception: pass
' >/dev/null 2>&1 &
  load_pid=$!
  BACKGROUND_PID="$load_pid"
  scaled=0
  for _ in $(seq 1 40); do
    desired="$(k get hpa/flask-app -o jsonpath='{.status.desiredReplicas}' 2>/dev/null || echo 0)"
    [[ "$desired" =~ ^[0-9]+$ && "$desired" -gt 3 ]] && { scaled=1; break; }
    sleep 4
  done
  wait "$load_pid" 2>/dev/null || true
  BACKGROUND_PID=""
  k get hpa/flask-app
  [[ "$scaled" == 1 ]] || { fail 'HPA did not request more than 3 replicas under bounded load'; exit 1; }
else
  info 'HPA CPU metrics proved. Actual scale-out NOT tested (set K8S_HPA_LOAD=1 to exercise it).'
fi
step 'Remove only validation-owned HPA (Deployment and Service remain)'
assert_eq "$(owner_of "$PROFILE" default hpa/flask-app)" kubernetes-in-practice
k delete hpa/flask-app
summary
