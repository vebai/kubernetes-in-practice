#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'Kubernetes context:'
kubectl config current-context
printf '%s\n' 'Cluster nodes:'
kubectl get nodes
printf '%s\n' 'Visible namespaces:'
kubectl get namespaces
if command -v aws >/dev/null 2>&1; then
  printf '%s\n' 'AWS identity (if configured):'
  aws sts get-caller-identity || true
fi
