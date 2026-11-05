#!/usr/bin/env bash
# Live Chapter 10. CREATES BILLABLE AWS resources. Never run without approvals.
set -Eeuo pipefail
umask 077
source "$(dirname "$0")/common.sh"
step 'Chapter 10 LIVE — verify charge approval, environment and exact AWS account'
need_yes K8S_AWS_CHARGE_APPROVAL "${K8S_AWS_CHARGE_APPROVAL:-}" I_ACCEPT_EKS_CHARGES
need_yes K8S_AWS_BUDGET_CONFIRMED "${K8S_AWS_BUDGET_CONFIRMED:-}" YES
for tool in aws eksctl docker kubectl helm python3 curl; do need "$tool"; done
check_files; check_account; check_allowed_cidr
versions="$(awsx eks describe-cluster-versions --query 'clusterVersions[].clusterVersion' --output text)" || stop 'Cannot verify supported EKS versions'
has_token "$versions" 1.36 || stop 'Book EKS version 1.36 unavailable in this AWS Region; stop before creating any resources'
info 'BILLABLE: EKS control plane, EC2/Auto Mode, ALB, public IPv4, and possible NAT networking will incur charges.'
step 'Check EKS cluster and ECR repository do not pre-exist; never adopt unknown resources'
clusters="$(awsx eks list-clusters --query 'clusters[]' --output text)"
! has_token "$clusters" flask-eks || stop 'flask-eks already exists. Do not overwrite/recreate; inspect ownership before resuming.'
repos="$(awsx ecr describe-repositories --query 'repositories[].repositoryName' --output text)"
! has_token "$repos" flask-app || stop 'flask-app ECR repo already exists. Inspect it and choose a controlled reuse plan.'
step 'Create only book-lab ECR repository, build amd64 image, push immutable tag'
awsx ecr create-repository --repository-name "$ECR_REPOSITORY" --image-tag-mutability IMMUTABLE \
  --tags Key=book-lab,Value=kubernetes-in-practice --query 'repository.repositoryUri' --output text
echo "$ACTUAL_ACCOUNT" > "$STATE_DIR/ecr-created.account"
REGISTRY="${ACTUAL_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
awsx ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY"
docker build --platform linux/amd64 -t "$REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" ./flask-app/versions/v2.3.0
docker push "$REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
awsx ecr describe-images --repository-name "$ECR_REPOSITORY" --image-ids "imageTag=$IMAGE_TAG" \
  --query 'imageDetails[].{digest:imageDigest,pushed:imagePushedAt}' --output table
step 'Create exact book EKS Auto Mode cluster; mark creation request before invoking eksctl'
echo "$ACTUAL_ACCOUNT" > "$STATE_DIR/cluster-create-requested.account"
info 'If this command fails, stop and inspect CloudFormation/EKS; partial AWS resources may still be billable.'
eksctl create cluster -f eks/cluster.yaml --kubeconfig "$KUBECONFIG_PATH"
step 'Establish isolated kubeconfig; do not change the global ~/.kube/config'
awsx eks update-kubeconfig --name "$CLUSTER_NAME" --alias "$KCTX" --kubeconfig "$KUBECONFIG_PATH"
chmod 600 "$KUBECONFIG_PATH"
check_created_cluster
awsx eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.{name:name,status:status,version:version,endpoint:endpoint}' --output table
step 'Install EKS Auto Mode ALB IngressClass; install Helm release with the real ECR image'
render_restricted_ingress_params
k apply -f "$STATE_DIR/alb-ingress-params-restricted.yaml"
k apply -f eks/alb-ingress-class.yaml
k create namespace flask --dry-run=client -o yaml | k apply -f -
h lint helm/flask-app -f eks/values-eks.yaml --set-string "image.repository=$REGISTRY/$ECR_REPOSITORY"
h template flask-app helm/flask-app --namespace flask -f eks/values-eks.yaml \
  --set-string "image.repository=$REGISTRY/$ECR_REPOSITORY" > "$STATE_DIR/helm-ch10-render.yaml"
h upgrade --install flask-app helm/flask-app --namespace flask -f eks/values-eks.yaml \
  --set-string "image.repository=$REGISTRY/$ECR_REPOSITORY" --wait --timeout 18m
k -n flask rollout status deployment/flask-app --timeout=240s
k -n flask get deploy,pods,svc,ingress,hpa,pdb -o wide
step 'Verify metrics-server add-on; install only when absent'
addons="$(awsx eks list-addons --cluster-name "$CLUSTER_NAME" --query 'addons[]' --output text)"
if ! has_token "$addons" metrics-server; then
  info 'EKS does not ship Metrics Server universally. Installing AWS community add-on for HPA evidence.'
  awsx eks create-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server >/dev/null
  echo "$ACTUAL_ACCOUNT" > "$STATE_DIR/metrics-addon-created.account"
fi
for attempt in $(seq 1 60); do
  status="$(awsx eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server --query addon.status --output text 2>/dev/null || true)"
  if [[ "$status" == ACTIVE ]]; then info "Metrics Server add-on ACTIVE on attempt $attempt"; break; fi
  if [[ "$status" == CREATE_FAILED || "$status" == DELETE_FAILED ]]; then
    awsx eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server \
      --query 'addon.{status:status,issues:health.issues}' --output json || true
    stop "Metrics Server add-on status=$status; inspect add-on health and Pods"
  fi
  info "Metrics Server add-on status=$status (poll $attempt/60); allowing initial node scheduling to settle"
  if [[ "$attempt" -eq 60 ]]; then
    awsx eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server \
      --query 'addon.{status:status,issues:health.issues}' --output json || true
    k -n kube-system get pods -o wide || true
    stop 'Metrics Server did not reach ACTIVE during the bounded recovery window; retain cluster for investigation'
  fi
  sleep 10
done
for attempt in $(seq 1 36); do
  if k -n flask top pods > "$STATE_DIR/metrics-pods.txt" 2>/dev/null; then
    cat "$STATE_DIR/metrics-pods.txt"; info "HPA resource metrics available on attempt $attempt"; break
  fi
  if [[ "$attempt" -eq 36 ]]; then stop 'Metrics Server ACTIVE but kubectl top pods unavailable'; fi
  sleep 10
done
step 'Verify AWS ALB hostname and actual /healthz HTTP response'
ALB_HOST=""
for attempt in $(seq 1 60); do
  ALB_HOST="$(k -n flask get ingress flask-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  if [[ -n "$ALB_HOST" ]]; then info "ALB DNS assigned on poll $attempt: $ALB_HOST"; break; fi
  [[ "$attempt" -ne 60 ]] || stop 'Ingress has no load balancer hostname; inspect describe ingress and AWS ALB provisioning'
  sleep 10
done
echo "$ALB_HOST" > "$STATE_DIR/alb-hostname.txt"
for attempt in $(seq 1 45); do
  if curl --fail --silent --show-error --connect-timeout 5 --max-time 12 "http://$ALB_HOST/healthz" > "$STATE_DIR/eks-health.json" 2>/dev/null && \
    python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"]=="alive"' "$STATE_DIR/eks-health.json"; then
    info "Public ALB HTTP /healthz PASS on attempt $attempt"; cat "$STATE_DIR/eks-health.json"; echo; break
  fi
  [[ "$attempt" -ne 45 ]] || stop 'ALB /healthz did not return expected response; inspect ALB target health, pods and endpoint slices'
  sleep 10
done
step 'Chapter 10 LIVE PASS — preserve deployment for Chapters 11 and 12'
info "Account=$ACTUAL_ACCOUNT Region=$AWS_REGION Cluster=$CLUSTER_NAME ALB=$ALB_HOST"
info "Log: $LOG_FILE; AWS resources are still BILLABLE. Use 99-cleanup.sh after final validation."
