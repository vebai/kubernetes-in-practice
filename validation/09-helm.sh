#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=09
NAMESPACE=flask
source "$(dirname "$0")/lib.sh"
require helm
ensure_local_cluster
build_and_load v2.3.0 flask-app/versions/v2.3.0
step 'Helm chart lint, template and client-side structural validation'
helm lint helm/flask-app -f helm/values-development.yaml
RENDERED="$LOG_DIR/helm-development-${RUN_ID}.yaml"
helm template flask-app helm/flask-app --namespace flask -f helm/values-development.yaml > "$RENDERED"
kubectl --context="$PROFILE" create --dry-run=client --validate=false -f "$RENDERED" -o name
step 'Create an isolated Helm release namespace'
assert_safe_object "$PROFILE" default namespace/flask
kubectl --context="$PROFILE" apply -f <(kubectl create namespace flask --dry-run=client -o yaml)
kubectl --context="$PROFILE" annotate namespace/flask book.validation/owner=kubernetes-in-practice --overwrite >/dev/null
step 'Install or upgrade development chart and wait for app rollout'
helm --kube-context "$PROFILE" upgrade --install flask-app helm/flask-app -n flask \
  -f helm/values-development.yaml --wait --timeout 6m
helm --kube-context "$PROFILE" status flask-app -n flask
k rollout status deployment/flask-app --timeout=240s
k get deployment,pods,service,configmap -o wide
step 'Verify readiness, version and in-cluster Service DNS'
assert_contains "$(app_get 'http://flask-app.flask.svc.cluster.local/healthz')" alive
assert_app_value version v2.3.0
assert_app_value message 'Hello from development'
if [[ "${K8S_HELM_CLEANUP:-0}" == 1 ]]; then
  step 'Optional cleanup of only this dedicated Helm release'
  helm --kube-context "$PROFILE" uninstall flask-app -n flask --wait
else
  info 'Helm release retained for troubleshooting. K8S_HELM_CLEANUP=1 opts into release removal.'
fi
summary
