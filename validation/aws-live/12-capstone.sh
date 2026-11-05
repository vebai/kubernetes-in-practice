#!/usr/bin/env bash
# Live Chapter 12. Mutates ONLY the book-owned Helm release and one managed Pod.
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
step 'Chapter 12 LIVE — verify account and separate deliberate fault approval'
need_yes K8S_AWS_FAULT_APPROVAL "${K8S_AWS_FAULT_APPROVAL:-}" I_ACCEPT_CONTROLLED_LAB_FAULTS
for tool in aws kubectl helm python3 curl; do need "$tool"; done
check_created_cluster; check_files
REGISTRY="${ACTUAL_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ALB_HOST="$(k -n flask get ingress flask-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
[[ -n "$ALB_HOST" ]] || stop 'Chapter 10 ALB hostname missing'
step 'Record current Helm history, then deploy more demanding capstone values'
h history flask-app -n flask
h lint helm/flask-app -f eks/values-capstone.yaml --set-string "image.repository=$REGISTRY/$ECR_REPOSITORY"
h template flask-app helm/flask-app -n flask -f eks/values-capstone.yaml \
  --set-string "image.repository=$REGISTRY/$ECR_REPOSITORY" > "$STATE_DIR/helm-ch12-render.yaml"
h upgrade flask-app helm/flask-app -n flask -f eks/values-capstone.yaml \
  --set-string "image.repository=$REGISTRY/$ECR_REPOSITORY" --wait --timeout 18m
k -n flask rollout status deploy/flask-app --timeout=240s
k -n flask get deploy,pods,hpa,pdb,ingress -o wide
step 'Assert capstone HPA min=3, PDB minAvailable=2 and zone-spread configuration'
k -n flask get hpa flask-app -o json > "$STATE_DIR/ch12-hpa.json"
k -n flask get pdb flask-app -o json > "$STATE_DIR/ch12-pdb.json"
k -n flask get deploy flask-app -o json > "$STATE_DIR/ch12-deployment.json"
python3 - "$STATE_DIR" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1]); load=lambda n:json.loads((p/n).read_text())
h=load('ch12-hpa.json'); b=load('ch12-pdb.json'); d=load('ch12-deployment.json')
assert h['spec']['minReplicas']==3
assert b['spec']['minAvailable']==2
assert any(x['topologyKey']=='topology.kubernetes.io/zone' for x in d['spec']['template']['spec'].get('topologySpreadConstraints',[]))
assert d['status'].get('availableReplicas',0)>=3
print('Capstone controls and 3 available replicas: PASS')
PY
info 'Spread constraint uses ScheduleAnyway: verify actual AZ distribution; manifest alone does not guarantee two-AZ placement.'
k -n flask get pods -o wide -l app.kubernetes.io/instance=flask-app
step 'Controlled recovery: delete ONE owned Deployment Pod and prove a different Ready Pod appears'
k -n flask get pods -l app.kubernetes.io/instance=flask-app -o json > "$STATE_DIR/ch12-pods-before.json"
POD="$(python3 - "$STATE_DIR/ch12-pods-before.json" <<'PY'
import json,sys
items=json.load(open(sys.argv[1]))['items']; good=[p['metadata']['name'] for p in items if p.get('status',{}).get('phase')=='Running']
assert len(good)>=3,'Expected >=3 owned app Pods';print(sorted(good)[0])
PY
)"
info "Deleting only: namespace flask / Pod $POD (owned by Helm Deployment)"
k -n flask delete "pod/$POD" --wait=false
for attempt in $(seq 1 60); do
  k -n flask get pods -l app.kubernetes.io/instance=flask-app -o json > "$STATE_DIR/ch12-pods-after.json"
  if python3 - "$STATE_DIR/ch12-pods-after.json" "$POD" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))['items']; deleted=sys.argv[2]
ready=[p['metadata']['name'] for p in x if p['metadata'].get('deletionTimestamp') is None and p.get('status',{}).get('phase')=='Running' and any(c.get('type')=='Ready' and c.get('status')=='True' for c in p['status'].get('conditions',[]))]
sys.exit(0 if deleted not in [p['metadata']['name'] for p in x] and len(ready)>=3 else 1)
PY
  then info "Replacement verified on poll $attempt"; break; fi
  if [[ "$attempt" -eq 60 ]]; then
    k -n flask get pods -l app.kubernetes.io/instance=flask-app -o wide || true
    stop 'Replacement Pod not verified in time; retain cluster for investigation'
  fi
  sleep 5
done
k -n flask rollout status deploy/flask-app --timeout=240s
curl --fail --silent --show-error --max-time 25 "http://$ALB_HOST/healthz" > "$STATE_DIR/ch12-health-after-pod-replacement.json"
python3 - "$STATE_DIR/ch12-health-after-pod-replacement.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['status']=='alive'
print('External ALB healthy after Pod replacement: PASS')
PY
step 'Controlled Helm failure: impossible image, expected failed upgrade, automatic rollback'
# Helm 4 renamed --atomic to --rollback-on-failure; use its supported spelling
# while retaining backward compatibility with the book's Helm 3 readers.
rollback_flag=--atomic
if helm version --short | grep -Eq '^v4\.'; then rollback_flag=--rollback-on-failure; fi
if h upgrade flask-app helm/flask-app -n flask -f eks/values-capstone.yaml \
     --set-string "image.repository=$REGISTRY/$ECR_REPOSITORY" \
     --set-string image.tag=validation-intentionally-missing-9999 \
     --set-string image.pullPolicy=Always "$rollback_flag" --timeout 180s; then
  stop 'Deliberately broken image upgrade unexpectedly succeeded: investigate image/tag and Helm history'
else
  info "Expected failed Helm upgrade observed; $rollback_flag requested rollback."
fi
k -n flask rollout status deploy/flask-app --timeout=300s
live_image="$(k -n flask get deploy flask-app -o jsonpath='{.spec.template.spec.containers[0].image}')"
[[ "$live_image" == "$REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" ]] || stop "Rollback did not restore expected image; got $live_image"
h status flask-app -n flask
h history flask-app -n flask
curl --fail --silent --show-error --max-time 25 "http://$ALB_HOST/healthz" > "$STATE_DIR/ch12-health-after-rollback.json"
python3 - "$STATE_DIR/ch12-health-after-rollback.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['status']=='alive'
print('External ALB healthy after rollback: PASS')
PY
step 'Chapter 12 LIVE PASS — capstone, Pod recovery, failed rollout and Helm rollback'
info "Log: $LOG_FILE. Cluster is STILL BILLABLE; clean up deliberately with 99-cleanup.sh."
