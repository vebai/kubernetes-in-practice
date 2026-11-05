#!/usr/bin/env bash
# Resume Chapter 10 verification ONLY after EKS, ECR, Helm and Ingress exist.
# Read-only: no AWS or Kubernetes resource creates, updates or deletes.
set -Eeuo pipefail
umask 077
source "$(dirname "$0")/common.sh"

step 'Resume existing Chapter 10 deployment — READ ONLY; never recreate EKS/ECR/Helm'
for tool in aws kubectl helm python3 curl; do need "$tool"; done
check_created_cluster

step 'Confirm existing book-owned Helm release, image, Pods, and public Ingress'
REGISTRY="${ACTUAL_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
EXPECTED_IMAGE="$REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
actual_image="$(k -n flask get deployment flask-app -o jsonpath='{.spec.template.spec.containers[0].image}')" || stop 'The Flask Deployment is missing'
[[ "$actual_image" == "$EXPECTED_IMAGE" ]] || stop "Unexpected Deployment image: $actual_image (expected $EXPECTED_IMAGE)"
h status flask-app -n flask
k -n flask rollout status deployment/flask-app --timeout=180s
k -n flask get deploy,pods,svc,ingress,hpa,pdb -o wide

show_metric_diagnostics() {
  step 'Read-only Metrics Server diagnostics — add-on health, Pods, APIService, events'
  awsx eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server \
    --query 'addon.{name:addonName,status:status,version:addonVersion,issues:health.issues}' --output json || true
  k -n kube-system get deployment metrics-server -o wide || true
  k -n kube-system get pods -o wide || true
  k get apiservice v1beta1.metrics.k8s.io -o wide || true
  k -n kube-system describe deployment metrics-server || true
  k -n kube-system logs deployment/metrics-server --tail=100 || true
  k -n kube-system get events --sort-by=.lastTimestamp | tail -n 35 || true
  k get nodes -o wide || true
  k -n flask get hpa flask-app -o wide || true
  k -n flask top pods || true
}

step 'Inspect EKS Metrics Server add-on state; allow transient DEGRADED to recover'
awsx eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server \
  --query 'addon.{name:addonName,status:status,version:addonVersion,issues:health.issues}' --output json
# Newly provisioned EKS Auto Mode nodes and add-on workloads may take time to settle.
# A DEGRADED observation is logged but is not proof of a permanently failed add-on.
addon_active=0
for attempt in $(seq 1 36); do
  addon_status="$(awsx eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server --query addon.status --output text)" \
    || stop 'Could not read Metrics Server add-on status'
  info "Metrics Server status=$addon_status (poll $attempt/36)"
  if [[ "$addon_status" == ACTIVE ]]; then addon_active=1; break; fi
  if [[ "$addon_status" == CREATE_FAILED || "$addon_status" == DELETE_FAILED ]]; then
    show_metric_diagnostics
    stop "Metrics Server reached terminal failure state $addon_status. Do not recreate it blindly."
  fi
  if [[ "$addon_status" != CREATING && "$addon_status" != DEGRADED && "$addon_status" != UPDATING ]]; then
    show_metric_diagnostics
    stop "Unexpected Metrics Server add-on state: $addon_status"
  fi
  sleep 10
done
if [[ "$addon_active" -ne 1 ]]; then
  show_metric_diagnostics
  stop 'Metrics Server did not become ACTIVE within six minutes; inspect diagnostics before any repair'
fi
info 'Metrics Server EKS add-on ACTIVE'

step 'Verify actual Pod resource metrics and HPA ScalingActive evidence'
metrics_ready=0
for attempt in $(seq 1 36); do
  if k -n flask top pods > "$STATE_DIR/ch10-resume-top-pods.txt" 2> "$STATE_DIR/ch10-resume-top-error.txt"; then
    cat "$STATE_DIR/ch10-resume-top-pods.txt"
    metrics_ready=1
    info "Metrics API available (poll $attempt/36)"
    break
  fi
  info "Metrics API not ready yet (poll $attempt/36): $(tail -n 1 "$STATE_DIR/ch10-resume-top-error.txt")"
  sleep 10
done
if [[ "$metrics_ready" -ne 1 ]]; then
  show_metric_diagnostics
  stop 'Metrics Server is ACTIVE but kubectl top is unavailable; inspect logs'
fi
hpa_ready=0
for attempt in $(seq 1 36); do
  k -n flask get hpa flask-app -o json > "$STATE_DIR/ch10-resume-hpa.json"
  if python3 - "$STATE_DIR/ch10-resume-hpa.json" <<'PY'
import json,sys
h=json.load(open(sys.argv[1])); s=h.get('status') or {}
conditions={c.get('type'):c.get('status') for c in (s.get('conditions') or [])}
assert conditions.get('ScalingActive') == 'True', 'HPA ScalingActive not yet True'
assert s.get('currentMetrics'), 'HPA currently lacks CPU metrics'
PY
  then
    hpa_ready=1
    info "HPA ScalingActive and currentMetrics confirmed (poll $attempt/36)"
    k -n flask get hpa flask-app
    break
  fi
  sleep 10
done
[[ "$hpa_ready" -eq 1 ]] || stop 'Metrics Server works, but HPA still has no current CPU metrics'

step 'Verify real ALB DNS and two external HTTP responses'
ALB_HOST="$(k -n flask get ingress flask-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')" || stop 'Cannot read lab Ingress'
[[ -n "$ALB_HOST" ]] || stop 'Ingress has no AWS ALB hostname'
info "Existing ALB DNS: $ALB_HOST"
echo "$ALB_HOST" > "$STATE_DIR/alb-hostname.txt"
http_ok=0
for attempt in $(seq 1 36); do
  if curl --fail --silent --show-error --connect-timeout 5 --max-time 12 \
    "http://$ALB_HOST/healthz" > "$STATE_DIR/eks-health.json" 2> "$STATE_DIR/ch10-resume-http-error.txt" && \
    python3 - "$STATE_DIR/eks-health.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['status']=='alive'
PY
  then
    http_ok=1
    info "ALB public /healthz HTTP verified (poll $attempt/36)"
    cat "$STATE_DIR/eks-health.json"; echo
    break
  fi
  info "ALB /healthz not verified yet (poll $attempt/36): $(tail -n 1 "$STATE_DIR/ch10-resume-http-error.txt" 2>/dev/null || true)"
  sleep 10
done
if [[ "$http_ok" -ne 1 ]]; then
  k -n flask describe ingress flask-app || true
  k -n flask get endpointslice -o wide || true
  stop 'ALB did not deliver healthy /healthz HTTP. Check CIDR, ALB target groups and health checks.'
fi
curl --fail --silent --show-error --connect-timeout 5 --max-time 25 \
  "http://$ALB_HOST/" > "$STATE_DIR/ch10-resume-root.json" \
  || stop 'ALB / request failed'
python3 - "$STATE_DIR/ch10-resume-root.json" <<'PY'
import json,sys
v=json.load(open(sys.argv[1]))
assert v.get('version')=='v2.3.0', f'Unexpected application version: {v.get("version")}'
print('ALB / returned expected application version:', v['version'])
PY

step 'CHAPTER 10 LIVE PASS — pre-existing EKS, HPA metrics, and actual external ALB traffic'
info "Existing AWS resources remain BILLABLE. Next: bash validation/aws-live/11-observe.sh"
info "Log: $LOG_FILE"
