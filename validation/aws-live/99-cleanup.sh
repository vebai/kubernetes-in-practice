#!/usr/bin/env bash
# Destructive cleanup ONLY for a cluster created by this AWS LIVE pack.
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
step 'AWS cleanup — explicit authorisation and exact account/cluster identity'
need_yes K8S_AWS_DELETE_APPROVAL "${K8S_AWS_DELETE_APPROVAL:-}" DELETE_flask-eks_eu-west-2
for tool in aws eksctl kubectl helm python3; do need "$tool"; done
check_created_cluster
step 'Capture application Ingress ALB DNS and list resources before deletion'
ALB_HOST="$(k -n flask get ingress flask-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
info "Lab ALB hostname: ${ALB_HOST:-none}"
k -n flask get deployment,ingress,svc -o wide
h list -n flask
step 'Remove ONLY this lab Helm release; ingress deletion must precede cluster deletion'
if h status flask-app -n flask >/dev/null 2>&1; then
  h uninstall flask-app -n flask --wait --timeout 10m
else
  info 'Helm release not found; inspect remaining Ingress before continuing.'
fi
remaining_ingress="$(k -n flask get ingress flask-app -o name --ignore-not-found)"
[[ -z "$remaining_ingress" ]] || stop 'Lab Ingress still exists; cannot safely remove the EKS cluster'
step 'Verify book ALB actually disappeared from AWS before destroying the cluster'
if [[ -n "$ALB_HOST" ]]; then
  for attempt in $(seq 1 90); do
    if awsx elbv2 describe-load-balancers --output json | python3 -c 'import json,sys; host=sys.argv[1]; x=json.load(sys.stdin); sys.exit(any(v.get("DNSName")==host for v in x.get("LoadBalancers",[])))' "$ALB_HOST"; then
      info "ALB no longer present in ELB inventory (poll $attempt)"
      break
    fi
    [[ "$attempt" -ne 90 ]] || stop 'ALB still exists after 15 minutes. Check target groups/security groups and inspect before EKS deletion'
    sleep 10
  done
fi
step 'Remove only lab-created IngressClass and IngressClassParams'
k delete -f eks/alb-ingress-class.yaml --ignore-not-found
k delete -f eks/alb-ingress-class-params.yaml --ignore-not-found
step 'Delete ONLY this book-created EKS cluster via eksctl and wait for CloudFormation cleanup'
eksctl delete cluster -f eks/cluster.yaml --wait
for attempt in $(seq 1 30); do
  clusters="$(awsx eks list-clusters --query 'clusters[]' --output text)"
  if ! has_token "$clusters" flask-eks; then info 'EKS cluster no longer listed'; break; fi
  [[ "$attempt" -ne 30 ]] || stop 'EKS cluster still present; inspect EKS and CloudFormation'
  sleep 10
done
step 'Optional deletion of ONLY ECR repo created by this pack, with exact tag inventory guard'
if [[ "${K8S_AWS_DELETE_ECR:-NO}" == YES ]]; then
  [[ -f "$STATE_DIR/ecr-created.account" ]] || stop 'No lab ECR ownership marker; refusing ECR deletion'
  [[ "$(cat "$STATE_DIR/ecr-created.account")" == "$ACTUAL_ACCOUNT" ]] || stop 'ECR ownership marker belongs to another account'
  awsx ecr describe-images --repository-name "$ECR_REPOSITORY" --query 'imageDetails[].imageTags' --output json > "$STATE_DIR/ecr-tags-before-delete.json"
  python3 - "$STATE_DIR/ecr-tags-before-delete.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert all(set(tags or []) <= {'v2.3.0'} for tags in x), 'Other image tags present; do not delete ECR repo'
PY
  awsx ecr delete-repository --repository-name "$ECR_REPOSITORY" --force --query repository.repositoryName --output text
  info 'Book-created ECR repository deleted.'
else
  info 'ECR repository retained; it can incur storage charges. Set K8S_AWS_DELETE_ECR=YES only after reviewing images.'
fi
step 'Review remaining AWS resources and billing; absence of EKS is not proof of zero charges'
info 'In AWS Console verify: CloudFormation eksctl stacks; EC2/VPC NAT gateways, Elastic IPs and security groups; ALB/target groups; ECR; CloudWatch logs.'
info 'Account billing is delayed. Budgets warn but do not cap spending.'
info "Cleanup script complete. Log: $LOG_FILE"
