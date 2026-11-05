#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=08
source "$(dirname "$0")/lib.sh"
ensure_local_cluster
[[ -n "$(docker image ls -q flask-app:v2.2.0)" ]] || { fail 'Run Chapter 06 first'; exit 1; }
mk image load flask-app:v2.2.0
step 'Establish known-good Chapter 6 workload for all diagnosis exercises'
assert_eq "$(owner_of "$PROFILE" default deployment/flask-app)" kubernetes-in-practice
assert_eq "$(owner_of "$PROFILE" default service/flask-app)" kubernetes-in-practice
restore_six
if [[ "$FAULTS" != 1 ]]; then
  info 'K8S_FAULTS=0: controlled fault experiments skipped; baseline checked.'
  summary; exit 0
fi
step 'Fault 1: missing image; inspect Pod reason before repair'
k set image deployment/flask-app flask=flask-app:invalid-lab-image
wait_bad_pod 'ErrImageNeverPull|ImagePullBackOff|InvalidImageName'
k get events --sort-by=.lastTimestamp | tail -n 20
restore_six
step 'Fault 2: missing referenced ConfigMap; prove configuration failure'
k delete configmap/flask-config
k rollout restart deployment/flask-app
wait_bad_pod 'CreateContainerConfigError'
k get pods -l app.kubernetes.io/name=flask-app
restore_six
step 'Fault 3: wrong readiness path; prove non-ready new Pods'
k patch deployment/flask-app --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/invalid-readiness-path"}]'
readiness_failure=0
for _ in $(seq 1 30); do
  if k get pods -l app.kubernetes.io/name=flask-app -o json | python3 -c '
import json,sys
s=json.load(sys.stdin)
items=s.get("items",[])
assert any(p.get("status",{}).get("phase")=="Running" and any(c.get("ready") is False for c in p.get("status",{}).get("containerStatuses",[])) for p in items)
' 2>/dev/null; then readiness_failure=1; break; fi
  sleep 3
done
[[ "$readiness_failure" == 1 ]] || { fail 'No non-ready Pod observed under invalid readiness probe'; exit 1; }
k get pods -l app.kubernetes.io/name=flask-app
restore_six
step 'Fault 4: wrong Service selector; observe empty endpoints'
k patch service/flask-app --type=merge -p '{"spec":{"selector":{"nonexistent-label":"yes"}}}'
check_service_empty
restore_six
step 'Fault 5: crash loop with invalid container command'
k patch deployment/flask-app --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/command","value":["/bin/sh","-c","exit 42"]}]'
wait_bad_pod 'CrashLoopBackOff|Error'
k get pods -l app.kubernetes.io/name=flask-app
restore_six
step 'Final request path and evidence'
assert_contains "$(app_get 'http://flask-app.default.svc.cluster.local/healthz')" alive
k get deployments,pods,services,endpointslices -o wide
summary
