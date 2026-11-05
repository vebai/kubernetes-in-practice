#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=07
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/rbac-check.sh"
ensure_security_cluster
step 'Create restricted shop Namespace without touching the earlier profile'
assert_safe_object "$SECURITY_PROFILE" default namespace/shop
kubectl --context="$SECURITY_PROFILE" apply -f manifests/chapter-07/namespace.yaml
kubectl --context="$SECURITY_PROFILE" annotate namespace/shop book.validation/owner=kubernetes-in-practice --overwrite >/dev/null
apply_owned "$SECURITY_PROFILE" shop configmap/flask-config manifests/chapter-07/flask-config.yaml
step 'Install least-privilege RBAC with safety checks'
for object in serviceaccount/config-reader role/flask-config-reader rolebinding/flask-config-reader; do
  assert_safe_object "$SECURITY_PROFILE" shop "$object"
done
ks apply -f manifests/chapter-07/rbac.yaml
for object in serviceaccount/config-reader role/flask-config-reader rolebinding/flask-config-reader; do
  ks annotate "$object" book.validation/owner=kubernetes-in-practice --overwrite >/dev/null
done
step 'Build hardened image directly in isolated security cluster'
require docker
docker build -t flask-app:v2.3.0 flask-app/versions/v2.3.0
ms image load flask-app:v2.3.0
step 'Apply restricted Deployment and ClusterIP Service'
apply_owned "$SECURITY_PROFILE" shop deployment/flask-app manifests/chapter-07/deployment-secure.yaml
apply_owned "$SECURITY_PROFILE" shop service/flask-app manifests/chapter-07/service.yaml
ks rollout status deployment/flask-app --timeout=300s
ks get deployment,pods,service -o wide
assert_contains "$(ks exec deployment/flask-app -- id)" 'uid=1001'
step 'Prove named ConfigMap access is allowed; Secrets access denied'
sa=system:serviceaccount:shop:config-reader
rbac_expect yes 'named ConfigMap flask-config' get configmaps/flask-config --as="$sa"
rbac_expect no 'unrelated ConfigMap' get configmaps/unrelated-config --as="$sa"
rbac_expect no 'ConfigMap listing' list configmaps --as="$sa"
rbac_expect no 'Secrets access' get secrets --as="$sa"
info 'All four RBAC decisions verified, including three expected denials'
step 'Prove NetworkPolicy with genuinely allowed and denied HTTP requests'
apply_owned "$SECURITY_PROFILE" shop pod/allowed-client manifests/chapter-07/test-client-allowed.yaml
apply_owned "$SECURITY_PROFILE" shop pod/denied-client manifests/chapter-07/test-client-denied.yaml
ks wait --for=condition=Ready pods/allowed-client --timeout=240s
ks wait --for=condition=Ready pods/denied-client --timeout=240s
# On reruns, remove only validation-owned policies to establish an unblocked baseline.
for policy in networkpolicy/default-deny-ingress networkpolicy/allow-frontend; do
  if ks get "$policy" >/dev/null 2>&1; then
    assert_eq "$(owner_of "$SECURITY_PROFILE" shop "$policy")" kubernetes-in-practice
    ks delete "$policy" --wait=true
  fi
done
client_http() {
  local client="$1" attempts="${2:-30}" i output=""
  for ((i=1; i<=attempts; i++)); do
    if output="$(ks exec "pod/$client" -- wget -qO- -T 6 http://flask-app.shop.svc.cluster.local/healthz 2>&1)" && [[ "$output" == *'alive'* ]]; then
      info "$client HTTP healthy on attempt $i/$attempts"
      return 0
    fi
    if (( i == 1 || i % 5 == 0 )); then
      info "$client HTTP not yet ready (attempt $i/$attempts)"
    fi
    sleep 2
  done
  info "Final $client HTTP result: $output"
  return 1
}
step 'Establish that BOTH clients can reach the Service before policy enforcement'
client_http allowed-client || { fail 'Allowed client cannot reach app before NetworkPolicy'; exit 1; }
client_http denied-client || { fail 'Denied client cannot reach app before NetworkPolicy; cannot prove policy caused denial'; exit 1; }
step 'Apply ingress policies and prove allowed traffic persists while denied traffic fails'
apply_owned "$SECURITY_PROFILE" shop networkpolicy/default-deny-ingress manifests/chapter-07/default-deny-ingress.yaml
apply_owned "$SECURITY_PROFILE" shop networkpolicy/allow-frontend manifests/chapter-07/allow-frontend.yaml
# Brief convergence wait for Calico policy programming.
sleep 8
client_http allowed-client || { fail 'Allowed client cannot reach app after policy enforcement'; exit 1; }
ks exec pod/denied-client -- nslookup flask-app.shop.svc.cluster.local
# Use multiple checks: a single transient failure is insufficient as policy evidence.
for ((attempt=1; attempt<=3; attempt++)); do
  if ks exec pod/denied-client -- wget -qO- -T 6 http://flask-app.shop.svc.cluster.local/healthz; then
    fail "network policy failed: denied client accessed restricted workload (attempt $attempt)"; exit 1
  fi
  info "Denied client blocked as expected (attempt $attempt/3)"
done
ks get networkpolicies -o wide
info 'Allowed traffic worked, denied traffic failed, and denied client DNS resolution succeeded.'
if [[ "${K8S_STOP_OTHER_PROFILE:-1}" == 1 ]]; then
  step 'Stop (do not delete) security profile to free resources for Chapter 8'
  ms stop
fi
info 'Security profile retained; restart it to inspect. Explicit cleanup requires checking ownership first.'
summary
