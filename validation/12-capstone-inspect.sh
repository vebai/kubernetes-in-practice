#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=12
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/aws-lib.sh"
step 'Validate Helm capstone configuration without provisioning cloud infrastructure'
render_eks_values eks/values-capstone.yaml "$LOG_DIR/eks-capstone-${RUN_ID}.yaml"
python3 - "$LOG_DIR/eks-capstone-${RUN_ID}.yaml" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
for x in ('topologySpreadConstraints:', 'topology.kubernetes.io/zone', 'minAvailable: 2', 'minReplicas: 3'):
    assert x in s, f'Capstone rendered manifest missing: {x}'
print('Rendered capstone has spread, PDB and HPA controls.')
PY
if [[ "$AWS_LIVE_READONLY" != 1 ]]; then
  info 'SKIPPED LIVE CH12: rendered control checks only; real EKS rollout/recovery/ALB traffic not validated.'
  summary; exit 0
fi
step 'Verify correct account and context before inspecting EKS release'
aws_eks_preflight
step 'Inspect release, required availability controls and observed Pod state'
eh status flask-app -n flask
eh history flask-app -n flask
ek rollout status deployment/flask-app --timeout=120s
ek get deployment,service,ingress,hpa,pdb,pods -o wide
minrep="$(ek get hpa/flask-app -o jsonpath='{.spec.minReplicas}')"
assert_eq "$minrep" 3
pdb="$(ek get pdb/flask-app -o jsonpath='{.spec.minAvailable}')"
assert_eq "$pdb" 2
spread="$(ek get deployment/flask-app -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].topologyKey}')"
assert_eq "$spread" topology.kubernetes.io/zone
if [[ -n "${K8S_EKS_TEST_URL:-}" ]]; then
  require curl
  case "$K8S_EKS_TEST_URL" in https://*|http://*) ;; *) fail 'K8S_EKS_TEST_URL must start with http:// or https://'; exit 1;; esac
  step 'Request optional user-specified external ALB health URL'
  curl --fail --show-error --silent --max-time 20 "$K8S_EKS_TEST_URL" | tee "$LOG_DIR/eks-external-response-${RUN_ID}.txt"
else
  info 'No external ALB HTTP check: set K8S_EKS_TEST_URL to an endpoint you have verified.'
fi
info 'No EKS Pod removal, Helm upgrade, rollback or cleanup was performed by this read-only inspection.'
summary
