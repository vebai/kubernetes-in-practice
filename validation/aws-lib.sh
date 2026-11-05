#!/usr/bin/env bash
# Read-only EKS helpers. No create/update/delete AWS or EKS resource commands.
set -Eeuo pipefail
AWS_REGION="${AWS_REGION:-eu-west-2}"
CLUSTER_NAME="${K8S_EKS_CLUSTER:-flask-eks}"
ECR_REPOSITORY="${K8S_ECR_REPOSITORY:-flask-app}"
IMAGE_TAG="${K8S_EKS_IMAGE_TAG:-v2.3.0}"
EKS_CONTEXT="${K8S_EKS_CONTEXT:-}"
AWS_LIVE_READONLY="${K8S_AWS_READONLY:-0}"
aws_eks_preflight() {
  [[ "$AWS_REGION" == eu-west-2 ]] || { fail "this book baseline uses eu-west-2; refusing unexpected AWS_REGION=$AWS_REGION"; return 1; }
  [[ "$AWS_LIVE_READONLY" == 1 ]] || { info 'AWS live checks skipped. Set K8S_AWS_READONLY=1 and K8S_EXPECTED_AWS_ACCOUNT to opt in.'; return 2; }
  require aws; require kubectl; require helm
  [[ -n "${K8S_EXPECTED_AWS_ACCOUNT:-}" && "${K8S_EXPECTED_AWS_ACCOUNT}" =~ ^[0-9]{12}$ ]] || {
    fail 'Set K8S_EXPECTED_AWS_ACCOUNT to your exact 12-digit AWS account ID'; return 1;
  }
  local actual
  actual="$(aws sts get-caller-identity --query Account --output text --region "$AWS_REGION")"
  assert_eq "$actual" "$K8S_EXPECTED_AWS_ACCOUNT"
  info "AWS account verified: $actual; Region: $AWS_REGION"
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
    --query 'cluster.{name:name,status:status,version:version,endpoint:endpoint}' --output table
  [[ -n "$EKS_CONTEXT" ]] || { fail 'Set K8S_EKS_CONTEXT to the existing, exact EKS kubectl context name'; return 1; }
  kubectl config get-contexts -o name | grep -Fx -- "$EKS_CONTEXT" >/dev/null || {
    fail "kubectl context '$EKS_CONTEXT' not found; configure it manually after identity verification"; return 1;
  }
  # Check kube-system identity against AWS cluster endpoint to prevent a misleading alias.
  local aws_endpoint kube_endpoint
  aws_endpoint="$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query cluster.endpoint --output text)"
  kube_endpoint="$(kubectl --context="$EKS_CONTEXT" config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
  assert_eq "$kube_endpoint" "$aws_endpoint"
  kubectl --context="$EKS_CONTEXT" get nodes
  info "EKS context verified by API server endpoint, not just alias: $EKS_CONTEXT"
}
ek() { kubectl --context="$EKS_CONTEXT" -n flask "$@"; }
eh() { helm --kube-context="$EKS_CONTEXT" "$@"; }
render_eks_values() {
  local values="$1" output="$2" repo_ref
  require helm
  repo_ref="111122223333.dkr.ecr.eu-west-2.amazonaws.com/flask-app"
  helm lint helm/flask-app -f "$values" --set "image.repository=$repo_ref"
  helm template flask-app helm/flask-app -n flask -f "$values" \
    --set "image.repository=$repo_ref" > "$output"
  grep -q 'kind: Ingress' "$output" || { fail 'EKS Helm render has no Ingress'; return 1; }
  grep -q 'kind: HorizontalPodAutoscaler' "$output" || { fail 'EKS Helm render has no HPA'; return 1; }
  grep -q 'kind: PodDisruptionBudget' "$output" || { fail 'EKS Helm render has no PDB'; return 1; }
  info "Rendered EKS chart safely with synthetic account ID: $output"
}
