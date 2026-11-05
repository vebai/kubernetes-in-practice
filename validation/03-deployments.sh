#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=03
source "$(dirname "$0")/lib.sh"
ensure_local_cluster
if ! docker image inspect flask-app:v1.0.0 >/dev/null 2>&1; then
  step 'Recover missing Chapter 1 image after Docker Desktop reset'
  docker build -t flask-app:v1.0.0 flask-app
fi
mk image load flask-app:v1.0.0
step 'Deploy three replicas, verify rolling strategy and readiness'
apply_owned "$PROFILE" default deployment/flask-app manifests/chapter-03/flask-deployment.yaml
wait_rollout
assert_eq "$(k get deployment/flask-app -o jsonpath='{.status.readyReplicas}')" 3
k get replicaset,pods -l app.kubernetes.io/name=flask-app -o wide
step 'Delete one owned workload Pod and verify reconciliation'
POD="$(k get pods -l app.kubernetes.io/name=flask-app -o jsonpath='{.items[0].metadata.name}')"
[[ -n "$POD" ]] || { fail 'No Deployment Pod found'; exit 1; }
k delete "pod/$POD" --wait=false
# kubectl wait with a label selector can capture the Pod that is being deleted.
# Waiting for that old Pod to become Ready is incorrect after successful replacement.
# Instead, poll the CURRENT Pod list: old name absent, exactly three non-deleting
# Pods, all Running and Ready. This tests real Deployment reconciliation.
step 'Wait for a different Pod to replace the deleted Pod and for all three Pods to be Ready'
recovered=0
for attempt in $(seq 1 80); do
  if k get pods -l app.kubernetes.io/name=flask-app -o json 2>/dev/null | \
      python3 -c '
import json, sys
old = sys.argv[1]
pods = json.load(sys.stdin).get("items", [])
assert len(pods) == 3, f"expected 3 Pods; observed {len(pods)}"
assert all(p["metadata"]["name"] != old for p in pods), "old Pod still exists"
assert all(not p["metadata"].get("deletionTimestamp") for p in pods), "terminating Pod remains"
assert all(p.get("status", {}).get("phase") == "Running" for p in pods), "Pod not Running"
assert all(any(c.get("type") == "Ready" and c.get("status") == "True"
               for c in p.get("status", {}).get("conditions", [])) for p in pods), "Pod not Ready"
' "$POD" 2>/dev/null; then
    recovered=1
    info "Reconciliation observed on poll $attempt: deleted $POD; three replacement/current Pods are Ready"
    break
  fi
  sleep 2
done
if [[ "$recovered" != 1 ]]; then
  k get pods -l app.kubernetes.io/name=flask-app -o wide || true
  fail "Deployment did not restore three Ready Pods after deleting $POD"; exit 1
fi
wait_rollout
assert_eq "$(k get deployment/flask-app -o jsonpath='{.status.readyReplicas}')" 3
assert_eq "$(k get deployment/flask-app -o jsonpath='{.status.availableReplicas}')" 3
k get pods -l app.kubernetes.io/name=flask-app -o wide
if [[ "$FAULTS" == 1 ]]; then
  step 'Controlled fault: deploy nonexistent image (imagePullPolicy Never)'
  k set image deployment/flask-app flask=flask-app:validation-missing-image
  wait_bad_pod 'ErrImageNeverPull|ImagePullBackOff|InvalidImageName'
  k get pods -l app.kubernetes.io/name=flask-app
  k get events --sort-by=.lastTimestamp | tail -n 20
  step 'Recover through rollout undo and source manifest'
  k rollout undo deployment/flask-app
  k apply -f manifests/chapter-03/flask-deployment.yaml
  wait_rollout
  assert_eq "$(k get deployment/flask-app -o jsonpath='{.status.readyReplicas}')" 3
fi
summary
