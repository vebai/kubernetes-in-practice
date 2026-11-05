#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=05
source "$(dirname "$0")/lib.sh"
ensure_local_cluster
k get deployment/flask-app >/dev/null || { fail 'Run Chapters 03–04 first'; exit 1; }
step 'Load ConfigMap and update existing Deployment'
apply_owned "$PROFILE" default configmap/flask-config manifests/chapter-05/flask-config.yaml
# Deployment remains owned from Chapter 03; fails safely if another workload owns its name.
apply_owned "$PROFILE" default deployment/flask-app manifests/chapter-05/flask-deployment-configured.yaml
wait_rollout
assert_app_value message 'Hello from a Kubernetes ConfigMap'
step 'Create and inspect disposable non-sensitive Secret without printing data'
if k get secret/flask-secret >/dev/null 2>&1; then
  assert_eq "$(owner_of "$PROFILE" default secret/flask-secret)" kubernetes-in-practice
  k delete secret/flask-secret
fi
k create secret generic flask-secret --from-literal=API_TOKEN=training-only-token
k annotate secret/flask-secret book.validation/owner=kubernetes-in-practice
k describe secret/flask-secret
step 'Remove the disposable lab Secret'
k delete secret/flask-secret
if [[ "$FAULTS" == 1 ]]; then
  step 'Controlled fault: delete required ConfigMap and restart workload'
  k delete configmap/flask-config
  k rollout restart deployment/flask-app
  wait_bad_pod 'CreateContainerConfigError'
  k get events --sort-by=.lastTimestamp | tail -n 25
  step 'Restore ConfigMap, reapply Deployment and verify runtime configuration'
  apply_owned "$PROFILE" default configmap/flask-config manifests/chapter-05/flask-config.yaml
  k apply -f manifests/chapter-05/flask-deployment-configured.yaml
  k rollout restart deployment/flask-app
  wait_rollout
  assert_app_value message 'Hello from a Kubernetes ConfigMap'
fi
summary
