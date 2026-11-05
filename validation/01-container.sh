#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=01
source "$(dirname "$0")/lib.sh"
require docker; require curl; require python3
docker info >/dev/null
NAME=book-k8s-validation-flask
HOST_PORT="${K8S_HOST_PORT:-18550}"

remove_owned_container() {
  if docker container inspect "$NAME" >/dev/null 2>&1; then
    [[ "$(docker inspect -f '{{index .Config.Labels "book.validation"}}' "$NAME")" == "kubernetes-in-practice" ]] || {
      fail "container $NAME exists but is not owned by this suite"; return 1;
    }
    docker rm -f "$NAME"
  fi
}
start_container() {
  local inner_port="$1"
  docker run -d --name "$NAME" --label book.validation=kubernetes-in-practice \
    -p "127.0.0.1:${HOST_PORT}:${inner_port}" \
    -e APP_NAME=flask-app -e APP_VERSION=v1.0.0 \
    -e APP_MESSAGE="Hello from Flask" flask-app:v1.0.0
}
wait_http() {
  local endpoint="$1" attempt body
  for attempt in $(seq 1 25); do
    if body="$(curl -fsS --max-time 3 "http://127.0.0.1:${HOST_PORT}${endpoint}" 2>/dev/null)"; then
      # Body to stdout for strict JSON verification; logging to stderr stays separate.
      printf '%s\n' "$body"
      printf '[HTTP] PASS %s after attempt %s/25\n' "$endpoint" "$attempt" >&2
      return 0
    fi
    sleep 1
  done
  printf '[HTTP] FAIL %s after 25 attempts; current container logs follow\n' "$endpoint" >&2
  docker logs "$NAME" --tail 35 >&2 || true
  fail "no valid HTTP response for $endpoint"; return 1
}
step 'Build Chapter 1 image'
docker build -t flask-app:v1.0.0 flask-app
docker image inspect flask-app:v1.0.0 >/dev/null
step 'Run, inspect identity and verify all endpoints'
remove_owned_container
start_container 5000
assert_eq "$(docker inspect -f '{{.Config.User}}' "$NAME")" '1001:1001'
docker exec "$NAME" id | grep -q 'uid=1001'
wait_http / | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x=={"app":"flask-app","message":"Hello from Flask","version":"v1.0.0"},x'
wait_http /healthz | python3 -c 'import json,sys; assert json.load(sys.stdin)["status"]=="alive"'
wait_http /readyz | python3 -c 'import json,sys; assert json.load(sys.stdin)["status"]=="ready"'
docker logs "$NAME" 2>&1 | tail -n 25
if docker logs "$NAME" 2>&1 | grep -q 'Control server error'; then
  printf '[WARN] Gunicorn control socket permission error; HTTP checks passed but source Dockerfiles need a targeted --no-control-socket review.\n' >&2
fi
if [[ "$FAULTS" == 1 ]]; then
  step 'Controlled fault: map host traffic to the wrong internal port'
  remove_owned_container
  start_container 5001
  sleep 3
  if curl --fail --silent --show-error --max-time 4 "http://127.0.0.1:${HOST_PORT}/healthz"; then
    fail 'misconfigured port mapping unexpectedly served HTTP'; exit 1
  fi
  docker port "$NAME"
  docker logs "$NAME" | tail -n 25
  step 'Repair the port mapping and repeat original checks'
  remove_owned_container
  start_container 5000
  wait_http /healthz | python3 -c 'import json,sys; assert json.load(sys.stdin)["status"]=="alive"'
fi
step 'Cleanup only validation-owned container; retain built image'
remove_owned_container
summary
