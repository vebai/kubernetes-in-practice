#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=11
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/aws-lib.sh"
step 'EKS read-only operational checks (no cluster creation)'
if [[ "$AWS_LIVE_READONLY" != 1 ]]; then
  info 'SKIPPED LIVE CH11: set K8S_AWS_READONLY=1; no EKS infrastructure was touched.'
  summary; exit 0
fi
aws_eks_preflight
step 'Inspect EKS add-ons and workload state'
aws eks list-addons --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION"
ek get nodes -L topology.kubernetes.io/zone
ek get deployment,pods,service,ingress,hpa,pdb -o wide
ek get events --sort-by=.lastTimestamp | tail -n 60
ek logs deployment/flask-app --tail=30
eh status flask-app -n flask
step 'Check ingress classes, storage classes, metrics and rollout'
ek get ingressclass
ek get storageclass
ek top pods
ek rollout status deployment/flask-app --timeout=120s
summary
