#!/usr/bin/env bash
# Shared AWS EKS book-validation guardrails. Source from other scripts.
set -Eeuo pipefail
AWS_LIVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$AWS_LIVE_DIR/../.." && pwd)"
cd "$REPO"
AWS_REGION="${AWS_REGION:-eu-west-2}"
export AWS_DEFAULT_REGION="$AWS_REGION" AWS_PAGER=""
CLUSTER_NAME=flask-eks
ECR_REPOSITORY=flask-app
IMAGE_TAG=v2.3.0
K8S_VERSION=1.36
KCTX=flask-eks-book-validation
STATE_DIR="$REPO/validation/.logs/aws-live"
mkdir -p "$STATE_DIR"
KUBECONFIG_PATH="$STATE_DIR/kubeconfig"
NOW="$(date -u '+%Y%m%dT%H%M%SZ')"
LOG_FILE="$STATE_DIR/$(basename "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}" .sh)-${NOW}.log"
# tee logging while preserving Bash pipeline failures
exec > >(tee -a "$LOG_FILE") 2>&1
step() { printf '\n[%s] === %s ===\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
stop() { printf '[BLOCKED] %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || stop "Missing $1; install it before continuing"; }
has_token() { printf '%s\n' "$1" | tr '[:space:]' '\n' | grep -Fxq -- "$2"; }
awsx() { aws --region "$AWS_REGION" "$@"; }
k() { kubectl --kubeconfig "$KUBECONFIG_PATH" --context "$KCTX" "$@"; }
h() { helm --kubeconfig "$KUBECONFIG_PATH" --kube-context "$KCTX" "$@"; }
check_region() { [[ "$AWS_REGION" == eu-west-2 ]] || stop "Only book baseline eu-west-2 is authorised; got $AWS_REGION"; }
check_account() {
  need aws; check_region
  [[ "${K8S_EXPECTED_AWS_ACCOUNT:-}" =~ ^[0-9]{12}$ ]] || stop 'Set K8S_EXPECTED_AWS_ACCOUNT to the 12-digit account ID you have approved'
  ACTUAL_ACCOUNT="$(awsx sts get-caller-identity --query Account --output text)" || stop 'AWS identity unavailable'
  [[ "$ACTUAL_ACCOUNT" == "$K8S_EXPECTED_AWS_ACCOUNT" ]] || stop "AWS account mismatch; active=$ACTUAL_ACCOUNT expected=$K8S_EXPECTED_AWS_ACCOUNT"
  export ACTUAL_ACCOUNT
  info "Confirmed account=$ACTUAL_ACCOUNT, region=$AWS_REGION, cluster=$CLUSTER_NAME"
}
check_kube_target() {
  [[ -f "$KUBECONFIG_PATH" ]] || stop "No isolated kubeconfig at $KUBECONFIG_PATH; run Chapter 10 first"
  [[ "$(kubectl --kubeconfig "$KUBECONFIG_PATH" config current-context)" == "$KCTX" ]] || stop 'Kubeconfig context is not the expected validation alias'
  local aws_endpoint kube_endpoint
  aws_endpoint="$(awsx eks describe-cluster --name "$CLUSTER_NAME" --query cluster.endpoint --output text)" || stop 'EKS cluster not readable'
  kube_endpoint="$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')" || stop 'Cannot inspect Kubernetes API endpoint'
  [[ "$aws_endpoint" == "$kube_endpoint" ]] || stop 'Kubernetes API endpoint differs from the expected AWS cluster'
}
check_created_cluster() {
  check_account
  [[ -f "$STATE_DIR/cluster-create-requested.account" ]] || stop 'No local ownership marker: refusing mutation of an unknown cluster'
  [[ "$(cat "$STATE_DIR/cluster-create-requested.account")" == "$ACTUAL_ACCOUNT" ]] || stop 'Cluster ownership/account marker mismatch'
  local status
  status="$(awsx eks describe-cluster --name "$CLUSTER_NAME" --query cluster.status --output text)" || stop 'Cluster not found'
  [[ "$status" == ACTIVE ]] || stop "Cluster status is $status; expected ACTIVE"
  local version mode
  version="$(awsx eks describe-cluster --name "$CLUSTER_NAME" --query cluster.version --output text)"
  mode="$(awsx eks describe-cluster --name "$CLUSTER_NAME" --query cluster.computeConfig.enabled --output text)"
  [[ "$version" == "$K8S_VERSION" && "$mode" == True ]] || stop "Cluster properties differ from the book baseline: version=$version AutoMode=$mode"
  check_kube_target
}
check_files() {
  for f in eks/cluster.yaml eks/values-eks.yaml eks/values-capstone.yaml eks/alb-ingress-class-params.yaml eks/alb-ingress-class.yaml helm/flask-app/Chart.yaml; do
    [[ -f "$f" ]] || stop "Missing repository source file $f"
  done
  grep -Eq '^  name: flask-eks$' eks/cluster.yaml || stop 'Cluster name differs from the book'
  grep -Eq '^  region: eu-west-2$' eks/cluster.yaml || stop 'Cluster Region differs from the book'
  grep -Eq '^  version: "1.36"$' eks/cluster.yaml || stop 'Cluster version differs from the book'
  grep -Eq '^  enabled: true$' eks/cluster.yaml || stop 'Cluster Auto Mode not enabled'
}
# Only permit one public IPv4 host to access the AWS ALB during the book lab.
# The address must be the public IPv4 used by the operator's outbound HTTP traffic.
check_allowed_cidr() {
  need python3
  [[ -n "${K8S_ALLOWED_CIDR:-}" ]] || stop 'Set K8S_ALLOWED_CIDR to YOUR public egress IPv4/32, e.g. 203.0.113.4/32 (example only); no wildcard ranges are permitted'
  python3 - "$K8S_ALLOWED_CIDR" <<'PYIP' || stop 'K8S_ALLOWED_CIDR must be a globally routable IPv4 /32 host route'
import ipaddress, sys
try:
    network=ipaddress.ip_network(sys.argv[1], strict=True)
    assert network.version == 4 and network.prefixlen == 32 and network.network_address.is_global
except (ValueError, AssertionError):
    sys.exit(1)
print('[ALB SCOPE] Allowed incoming IPv4:', network)
PYIP
}
render_restricted_ingress_params() {
  # No edits to the book's source YAML; write the restricted live class locally.
  check_allowed_cidr
  [[ -f eks/alb-ingress-class-params.yaml ]] || stop 'Missing source IngressClassParams'
  local output="$STATE_DIR/alb-ingress-params-restricted.yaml"
  cat > "$output" <<YAML
apiVersion: eks.amazonaws.com/v1
kind: IngressClassParams
metadata:
  name: alb
spec:
  scheme: internet-facing
  targetType: ip
  inboundCIDRs:
    - "$K8S_ALLOWED_CIDR"
YAML
  info "Restricted EKS Auto Mode ALB IngressClassParams generated: $output"
}
need_yes() { local key="$1" answer="$2" expected="$3"; [[ "$answer" == "$expected" ]] || stop "Set $key=$expected explicitly to authorise this operation"; }
