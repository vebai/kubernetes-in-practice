#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=02
source "$(dirname "$0")/lib.sh"
ensure_local_cluster
if ! docker image inspect flask-app:v1.0.0 >/dev/null 2>&1; then
  step 'Chapter 1 image absent from current Docker Engine; rebuild without repeating the fault exercise'
  docker build -t flask-app:v1.0.0 flask-app
  docker image inspect flask-app:v1.0.0 >/dev/null
else
  info 'Found previously validated flask-app:v1.0.0 in current Docker Engine'
fi
step 'Load image into exact Minikube profile'
mk image load flask-app:v1.0.0
step 'Apply standalone Pod and prove Ready'
apply_owned "$PROFILE" default pod/flask-app manifests/chapter-02/flask-pod.yaml
k wait --for=condition=Ready pod/flask-app --timeout=240s
k get pod flask-app -o wide
k describe pod/flask-app | tail -n 45
step 'Check Pod process identity and readiness HTTP'
assert_contains "$(k exec pod/flask-app -- id)" 'uid=1001'
assert_contains "$(k exec pod/flask-app -- python -c 'import urllib.request;print(urllib.request.urlopen("http://127.0.0.1:5000/healthz",timeout=5).read().decode())')" 'alive'
step 'Remove only validation-owned standalone Pod before Deployment chapter'
assert_eq "$(owner_of "$PROFILE" default pod/flask-app)" kubernetes-in-practice
k delete pod/flask-app --wait=true --timeout=120s
summary
