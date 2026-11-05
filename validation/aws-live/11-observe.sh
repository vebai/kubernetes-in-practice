#!/usr/bin/env bash
# Live Chapter 11. Read-only AWS/Kubernetes operational evidence.
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
step 'Chapter 11 LIVE — verify isolated AWS account and Kubernetes endpoint'
for tool in aws kubectl helm python3 curl; do need "$tool"; done
check_created_cluster
step 'Inspect cluster version, EKS Auto Mode configuration, ECR image digest and add-ons'
awsx eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.{status:status,version:version,compute:computeConfig,k8sNetwork:kubernetesNetworkConfig}' --output json
awsx ecr describe-images --repository-name "$ECR_REPOSITORY" --image-ids "imageTag=$IMAGE_TAG" \
  --query 'imageDetails[].{digest:imageDigest,tag:imageTags}' --output json
awsx eks list-addons --cluster-name "$CLUSTER_NAME" --output json
step 'Inspect Helm revision, Pod spread, rollout, Service and ingress'
h status flask-app -n flask
h history flask-app -n flask
k get nodes -L topology.kubernetes.io/zone
k -n flask rollout status deployment/flask-app --timeout=180s
k -n flask get deployment,pods,service,ingress,hpa,pdb -o wide
k -n flask get events --sort-by=.lastTimestamp | tail -n 50
step 'Prove Metrics Server and that HPA is receiving CPU metrics'
k -n flask top pods
for attempt in $(seq 1 36); do
  k -n flask get hpa flask-app -o json > "$STATE_DIR/ch11-hpa.json"
  if python3 - "$STATE_DIR/ch11-hpa.json" <<'PY'
import json,sys
h=json.load(open(sys.argv[1])); s=h.get('status') or {}
cs={c.get('type'):c.get('status') for c in s.get('conditions') or []}
assert cs.get('ScalingActive') == 'True'
assert s.get('currentMetrics'), 'HPA currently lacks resource metrics'
PY
  then info "HPA ScalingActive and current CPU metrics observed (poll $attempt)"; break
  fi
  [[ "$attempt" -ne 36 ]] || stop 'HPA lacks ScalingActive/currentMetrics after bounded polling'
  sleep 10
done
step 'Inspect AWS ALB target-group health (not merely Ingress creation)'
ALB_HOST="$(k -n flask get ingress flask-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
[[ -n "$ALB_HOST" ]] || stop 'Ingress has no ALB address'
ARN="$(awsx elbv2 describe-load-balancers --output json | python3 -c 'import json,sys; host=sys.argv[1]; x=json.load(sys.stdin); print(next((v["LoadBalancerArn"] for v in x.get("LoadBalancers",[]) if v.get("DNSName")==host),""))' "$ALB_HOST")"
[[ -n "$ARN" ]] || stop 'Cannot find ALB by the exact EKS Ingress hostname'
TG_ARN="$(awsx elbv2 describe-target-groups --load-balancer-arn "$ARN" --query 'TargetGroups[0].TargetGroupArn' --output text)"
[[ "$TG_ARN" == arn:* ]] || stop 'ALB has no target group'
awsx elbv2 describe-target-health --target-group-arn "$TG_ARN" --output json > "$STATE_DIR/ch11-target-health.json"
python3 - "$STATE_DIR/ch11-target-health.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])).get('TargetHealthDescriptions',[])
assert x, 'No ALB targets found'
states=[t['TargetHealth']['State'] for t in x]
print('ALB target states:', states)
assert 'healthy' in states, 'No ALB targets reported healthy'
PY
step 'Verify external traffic through actual ALB for both / and /healthz'
curl --fail --silent --show-error --max-time 25 "http://$ALB_HOST/healthz" > "$STATE_DIR/ch11-health.json"
python3 - "$STATE_DIR/ch11-health.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['status']=='alive'
print('External /healthz: PASS')
PY
curl --fail --silent --show-error --max-time 25 "http://$ALB_HOST/" > "$STATE_DIR/ch11-root.json"
python3 - "$STATE_DIR/ch11-root.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); print(x)
assert x['version']=='v2.3.0'
PY
step 'Chapter 11 LIVE PASS — read-only cluster, target and application evidence captured'
info "Log: $LOG_FILE. Cluster remains live and billable."
