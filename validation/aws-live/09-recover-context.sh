#!/usr/bin/env bash
# Recover local kubeconfig after a PARTIAL Stage 10 run. No AWS mutations.
set -Eeuo pipefail
umask 077
source "$(dirname "$0")/common.sh"
step 'Recover isolated EKS kubeconfig for a partially completed Chapter 10 lab'
check_account
[[ -f "$STATE_DIR/cluster-create-requested.account" ]] || stop 'No cluster creation marker; cannot claim ownership'
[[ "$(cat "$STATE_DIR/cluster-create-requested.account")" == "$ACTUAL_ACCOUNT" ]] || stop 'Ownership account marker mismatch'
status="$(awsx eks describe-cluster --name "$CLUSTER_NAME" --query cluster.status --output text)" || stop 'No EKS cluster exists; inspect CloudFormation and ECR instead'
[[ "$status" == ACTIVE ]] || stop "Cluster status=$status; not ACTIVE. Inspect AWS EKS/CloudFormation."
awsx eks update-kubeconfig --name "$CLUSTER_NAME" --alias "$KCTX" --kubeconfig "$KUBECONFIG_PATH"
chmod 600 "$KUBECONFIG_PATH"
check_kube_target
info "Isolated kubeconfig refreshed at $KUBECONFIG_PATH. AWS cluster unchanged."
