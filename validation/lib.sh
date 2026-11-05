#!/usr/bin/env bash
# Shared helpers for the Kubernetes in Practice validation suite.
# All live kubectl requests use an explicit context and namespace.
set -Eeuo pipefail

VALIDATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$VALIDATION_DIR/.." && pwd)"
[[ -f "$ROOT/flask-app/Dockerfile" && -d "$ROOT/manifests" ]] || {
  echo "ERROR: install the validation/ directory at the root of kubernetes-in-practice." >&2; exit 2;
}
cd "$ROOT"
CHAPTER="${CHAPTER:-unknown}"
PROFILE="${K8S_VALIDATION_PROFILE:-book-k8s-validation}"
SECURITY_PROFILE="${K8S_SECURITY_PROFILE:-book-k8s-security}"
NAMESPACE="${NAMESPACE:-default}"
RUN_ID="${K8S_VALIDATION_RUN_ID:-$(date '+%Y%m%d-%H%M%S')}"
LOG_DIR="${K8S_VALIDATION_LOG_DIR:-$VALIDATION_DIR/.logs}"
FAULTS="${K8S_FAULTS:-1}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/chapter-${CHAPTER}-${RUN_ID}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

LAST_CHECKPOINT="initialisation"
CURRENT_PROFILE="$PROFILE"
PF_PID=""
BACKGROUND_PID=""
ORIGINAL_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"

stamp() { date '+%Y-%m-%dT%H:%M:%S%z'; }
step() { LAST_CHECKPOINT="$*"; printf '\n[%s] [CH %s] === %s ===\n' "$(stamp)" "$CHAPTER" "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
fail() { printf '[FAIL] chapter=%s checkpoint=%s: %s\n' "$CHAPTER" "$LAST_CHECKPOINT" "$*" >&2; return 1; }
require() { command -v "$1" >/dev/null 2>&1 || { fail "missing executable: $1"; return 1; }; }
assert_eq() { [[ "$1" == "$2" ]] || { fail "expected [$2], got [$1]"; return 1; }; }
assert_contains() { [[ "$1" == *"$2"* ]] || { fail "expected substring [$2] in [$1]"; return 1; }; }

# NB: no implicit current context: this explicit context prevents accidental cloud mutations.
k() { kubectl --context="$PROFILE" -n "$NAMESPACE" "$@"; }
ks() { kubectl --context="$SECURITY_PROFILE" -n shop "$@"; }
mk() { minikube -p "$PROFILE" "$@"; }
ms() { minikube -p "$SECURITY_PROFILE" "$@"; }

safe_diagnostics() {
  local context="$1" ns="$2"
  command -v kubectl >/dev/null 2>&1 || return 0
  if ! kubectl config get-contexts -o name 2>/dev/null | grep -Fx -- "$context" >/dev/null; then
    info "Skipping cluster diagnostics: context '$context' was never created (check Minikube start output)."
    return 0
  fi
  kubectl --context="$context" -n "$ns" get deployments,pods,services,endpointslices,hpa 2>&1 || true
  kubectl --context="$context" -n "$ns" get events --sort-by=.lastTimestamp 2>&1 | tail -n 45 || true
  kubectl --context="$context" -n "$ns" describe deployment/flask-app 2>&1 | tail -n 80 || true
  kubectl --context="$context" -n "$ns" logs deployment/flask-app --tail=45 --all-containers=true 2>&1 || true
}
finish() {
  local rc="$1"
  if [[ -n "$PF_PID" ]]; then kill "$PF_PID" 2>/dev/null || true; wait "$PF_PID" 2>/dev/null || true; fi
  if [[ -n "$BACKGROUND_PID" ]]; then kill "$BACKGROUND_PID" 2>/dev/null || true; wait "$BACKGROUND_PID" 2>/dev/null || true; fi
  if [[ "$rc" -ne 0 ]]; then
    printf '\n[STOP] chapter %s failed at: %s (exit %s)\n' "$CHAPTER" "$LAST_CHECKPOINT" "$rc" >&2
    printf '[DIAGNOSTICS] preserving lab resources for investigation\n' >&2
    if [[ "$CHAPTER" != 01 && "$CHAPTER" != 10 && "$CHAPTER" != 11 && "$CHAPTER" != 12 ]]; then
      if [[ "$CHAPTER" == 07 ]]; then safe_diagnostics "$SECURITY_PROFILE" shop;
      elif [[ "$CHAPTER" == 09 ]]; then safe_diagnostics "$PROFILE" flask;
      else safe_diagnostics "$PROFILE" default; fi
    fi
  else
    printf '\n[PASS] chapter %s completed; log: %s\n' "$CHAPTER" "$LOG_FILE"
  fi
  if [[ -n "$ORIGINAL_CONTEXT" ]] && command -v kubectl >/dev/null 2>&1; then
    kubectl config use-context "$ORIGINAL_CONTEXT" >/dev/null 2>&1 || true
  fi
  return 0
}
trap 'finish "$?"' EXIT

require_local_tools() { require docker; require curl; require python3; require kubectl; require minikube; docker info >/dev/null; }

# Check Docker Desktop's ACTUAL VM limits; do not reduce the requested memory silently.
# A small margin is required for Docker's own processes outside the Minikube container.
check_docker_capacity() {
  local profile="$1" requested_mem="$2" requested_cpus="$3" bytes available_mem available_cpus reserve=256
  [[ "$requested_mem" =~ ^[0-9]+$ && "$requested_cpus" =~ ^[0-9]+$ ]] || {
    fail "K8S_*_MEMORY and K8S_*_CPUS must be positive integer values"; return 1;
  }
  if (( requested_mem < 3072 || requested_cpus < 2 )); then
    fail "profile $profile requested ${requested_mem} MiB / ${requested_cpus} CPU; use at least 3072 MiB and 2 CPUs for these labs"; return 1
  fi
  bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || true)"
  [[ "$bytes" =~ ^[0-9]+$ ]] || { fail 'Cannot read Docker Engine memory limit (docker info)'; return 1; }
  available_mem=$((bytes / 1024 / 1024))
  available_cpus="$(docker info --format '{{.NCPU}}' 2>/dev/null || true)"
  printf '[CAPACITY] profile=%s requested=%s MiB / %s CPUs; Docker provides=%s MiB / %s CPUs\n' \
    "$profile" "$requested_mem" "$requested_cpus" "$available_mem" "${available_cpus:-unknown}"
  if (( available_mem < requested_mem + reserve )); then
    printf '[BLOCKER] Docker Desktop memory is insufficient for the requested Minikube profile.\n' >&2
    printf '[ACTION] Docker Desktop > Settings > Resources > Advanced: increase Memory.\n' >&2
    printf '[ACTION] Alternatively, choose a smaller deliberate profile, e.g. K8S_LOCAL_MEMORY=4096, only if Docker has at least 4352 MiB.\n' >&2
    fail "Docker provides $available_mem MiB; $profile needs at least $((requested_mem + reserve)) MiB including the safety margin"; return 1
  fi
  if [[ "$available_cpus" =~ ^[0-9]+$ ]] && (( available_cpus < requested_cpus )); then
    fail "Docker provides $available_cpus CPUs; $profile needs $requested_cpus. Increase Docker Desktop CPUs or explicitly lower K8S_*_CPUS (minimum 2)"; return 1
  fi
}

# Reject outdated Minikube and unsupported kubectl/server skew before the lab changes workloads.
check_minikube_release() {
  local found minor
  found="$(minikube version --short 2>/dev/null || minikube version 2>/dev/null | head -n 1)"
  found="$(printf '%s\n' "$found" | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
  [[ -n "$found" ]] || { fail 'Unable to determine Minikube version; run minikube version'; return 1; }
  minor="$(printf '%s' "$found" | cut -d. -f2)"
  info "Installed Minikube: $found"
  if (( minor < 35 )); then
    fail "Minikube $found is too old for this validation baseline. Update Minikube (recommended v1.39.0 or newer), then recreate only the dedicated $PROFILE profile."; return 1
  fi
}
check_kubectl_server_skew() {
  local context="${1:-$PROFILE}" server_minor client_minor
  server_minor="$(kubectl --context="$context" get --raw /version | python3 -c 'import json,sys,re; d=json.load(sys.stdin); print(int(re.match(r"[0-9]+",d["minor"]).group()))')" || {
    fail "Unable to read Kubernetes server version for $context"; return 1;
  }
  client_minor="$(kubectl version --client -o json | python3 -c 'import json,sys,re; d=json.load(sys.stdin); v=d.get("clientVersion", d); print(int(re.search(r"1\.([0-9]+)",v.get("gitVersion", "")).group(1)))')" || {
    fail 'Unable to read kubectl client version'; return 1;
  }
  info "Kubernetes versions: API server 1.$server_minor; kubectl 1.$client_minor"
  if (( server_minor < 35 )); then
    fail "Server 1.$server_minor is outdated for these labs. Inspect and recreate only the dedicated $context validation profile after upgrading Minikube."; return 1
  fi
  if (( client_minor > server_minor + 1 || server_minor > client_minor + 1 )); then
    fail "kubectl/server version skew exceeds ±1 minor version (kubectl 1.$client_minor vs API server 1.$server_minor). Update Minikube or install a matching kubectl version."; return 1
  fi
}

# Profile creation is limited to a clearly named, purpose-built local learning profile.
ensure_local_cluster() {
  require_local_tools
  check_minikube_release
  if ! mk status >/dev/null 2>&1; then
    if [[ "${K8S_CREATE_LOCAL_PROFILE:-1}" != 1 ]]; then
      fail "profile $PROFILE is absent; set K8S_CREATE_LOCAL_PROFILE=1 to create it"; return 1
    fi
    step "Check Docker Desktop resources before creating local profile ($PROFILE)"
    check_docker_capacity "$PROFILE" "${K8S_LOCAL_MEMORY:-6144}" "${K8S_LOCAL_CPUS:-3}"
    step "Start isolated local Minikube profile ($PROFILE)"
    mk start --driver=docker --cpus="${K8S_LOCAL_CPUS:-3}" --memory="${K8S_LOCAL_MEMORY:-6144}"
  fi
  step "Verify selected local cluster is Ready ($PROFILE)"
  kubectl --context="$PROFILE" get nodes
  kubectl --context="$PROFILE" wait --for=condition=Ready nodes --all --timeout=180s
  check_kubectl_server_skew
}

ensure_security_cluster() {
  require_local_tools
  check_minikube_release
  [[ "$PROFILE" != "$SECURITY_PROFILE" ]] || { fail "main and security profile names must differ"; return 1; }
  if [[ "${K8S_STOP_OTHER_PROFILE:-1}" == 1 ]] && mk status >/dev/null 2>&1; then
    step "Stop main validation profile temporarily to make room for Calico"
    mk stop
  fi
  if ! ms status >/dev/null 2>&1; then
    if [[ "${K8S_CREATE_SECURITY_PROFILE:-1}" != 1 ]]; then
      fail "profile $SECURITY_PROFILE is absent; set K8S_CREATE_SECURITY_PROFILE=1"; return 1
    fi
    step "Check Docker Desktop resources before creating Calico profile ($SECURITY_PROFILE)"
    check_docker_capacity "$SECURITY_PROFILE" "${K8S_SECURITY_MEMORY:-4096}" "${K8S_SECURITY_CPUS:-2}"
    step "Start isolated Calico-enabled security profile ($SECURITY_PROFILE)"
    ms start --driver=docker --cpus="${K8S_SECURITY_CPUS:-2}" --memory="${K8S_SECURITY_MEMORY:-4096}" --cni=calico
  fi
  step "Verify separate security cluster Ready"
  kubectl --context="$SECURITY_PROFILE" get nodes
  kubectl --context="$SECURITY_PROFILE" wait --for=condition=Ready nodes --all --timeout=300s
  check_kubectl_server_skew "$SECURITY_PROFILE"
  # CNI enforcement is established by the allowed/denied traffic probes in Ch 07.
}

# Refuse to replace same-name objects that were not created by this test suite.
owner_of() {
  local context="$1" ns="$2" object="$3"
  kubectl --context="$context" -n "$ns" get "$object" -o json 2>/dev/null | \
    python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("metadata",{}).get("annotations",{}).get("book.validation/owner",""))' 2>/dev/null || true
}
assert_safe_object() {
  local context="$1" ns="$2" object="$3" existing
  if kubectl --context="$context" -n "$ns" get "$object" >/dev/null 2>&1; then
    existing="$(owner_of "$context" "$ns" "$object")"
    [[ "$existing" == "kubernetes-in-practice" ]] || { fail "refusing to overwrite pre-existing non-validation object $context/$ns/$object"; return 1; }
  fi
}
apply_owned() {
  local context="$1" ns="$2" object="$3" file="$4"
  assert_safe_object "$context" "$ns" "$object"
  kubectl --context="$context" -n "$ns" apply -f "$file"
  kubectl --context="$context" -n "$ns" annotate "$object" book.validation/owner=kubernetes-in-practice --overwrite >/dev/null
}

# Chapter 8's legacy restore path used plain `kubectl apply` and could remove
# the validation owner marker from the canonical Chapter 6 ConfigMap.
# Recover ONLY a matching, unmarked ConfigMap in this dedicated local lab,
# with BOTH Deployment and Service independently carrying our owner marker.
# An unrelated/unexpected object is never adopted or overwritten.
recover_canonical_configmap_owner() {
  local context="$1" ns="$2" manifest="$3" owner tmp
  [[ "$context" == book-k8s-validation && "$ns" == default ]] || {
    fail "ConfigMap recovery is restricted to book-k8s-validation/default; got $context/$ns"; return 1;
  }
  kubectl --context="$context" -n "$ns" get configmap/flask-config >/dev/null 2>&1 || return 0
  owner="$(owner_of "$context" "$ns" configmap/flask-config)"
  [[ "$owner" == kubernetes-in-practice ]] && return 0
  [[ -z "$owner" ]] || { fail 'ConfigMap is owned by another workflow; refusing adoption'; return 1; }
  tmp="$(mktemp -d)" || return 1
  if ! kubectl --context="$context" -n "$ns" get configmap/flask-config -o json > "$tmp/current.json" ||
     ! kubectl create --dry-run=client -f "$manifest" -o json > "$tmp/canonical.json" ||
     ! kubectl --context="$context" -n "$ns" get deployment/flask-app -o json > "$tmp/deploy.json" ||
     ! kubectl --context="$context" -n "$ns" get service/flask-app -o json > "$tmp/service.json" ||
     ! python3 "$VALIDATION_DIR/configmap-owner.py" "$tmp/current.json" "$tmp/canonical.json" "$tmp/deploy.json" "$tmp/service.json"; then
    rm -rf -- "$tmp"
    fail 'ConfigMap did not meet strict lab ownership-recovery rules'; return 1
  fi
  rm -rf -- "$tmp"
  kubectl --context="$context" -n "$ns" annotate configmap/flask-config book.validation/owner=kubernetes-in-practice --overwrite >/dev/null
  info 'Recovered missing owner annotation for exact canonical Chapter 6 lab ConfigMap'
}

build_and_load() {
  local tag="$1" folder="$2"
  step "Build flask-app:$tag and load into $PROFILE"
  docker build -t "flask-app:$tag" "$folder"
  mk image load "flask-app:$tag"
  docker image inspect "flask-app:$tag" >/dev/null
}

wait_rollout() {
  k rollout status deployment/flask-app --timeout="${ROLLOUT_TIMEOUT:-240s}"
  k get deployment/flask-app -o wide
}

# Runs HTTP requests inside the Flask Pod; no public ingress or port-forward needed.
app_get() {
  local url="${1:-http://127.0.0.1:5000/}"
  k exec deployment/flask-app -- python -c \
    'import sys,urllib.request; print(urllib.request.urlopen(sys.argv[1], timeout=7).read().decode())' "$url"
}
assert_app_value() {
  local key="$1" expected="$2" response
  response="$(app_get)"
  printf '%s\n' "$response"
  printf '%s' "$response" | python3 -c \
    'import json,sys; obj=json.load(sys.stdin); key=sys.argv[1]; value=sys.argv[2]; assert obj.get(key)==value, f"{key}: expected {value!r}, got {obj.get(key)!r}"' "$key" "$expected"
}
# This one parser is shared by the ready and empty checks. It handles
# absent/null EndpointSlice endpoints and never translates JSON errors to zero.
endpoint_ready_count() {
  local name="${1:-flask-app}"
  k get endpointslices -l "kubernetes.io/service-name=$name" -o json | \
    python3 "$VALIDATION_DIR/endpoint-count.py"
}
check_service_ready() {
  local name="${1:-flask-app}" count attempt
  for ((attempt=1; attempt<=40; attempt++)); do
    if ! count="$(endpoint_ready_count "$name")"; then
      fail "Unable to read ready EndpointSlice backends for $name (inspect preceding JSON/API error)"
      return 1
    fi
    if (( count > 0 )); then
      info "$count ready EndpointSlice backend(s)"
      return 0
    fi
    sleep 2
  done
  fail "no ready EndpointSlice backends for $name after about 80 seconds"
}
check_service_empty() {
  # Kubernetes removes endpoints asynchronously after a selector change.
  # Null/empty arrays are valid zero; malformed JSON is a real failure.
  local name="${1:-flask-app}" max_seconds="${K8S_ENDPOINT_DRAIN_TIMEOUT:-60}"
  local attempt max_attempts count
  [[ "$max_seconds" =~ ^[0-9]+$ ]] && (( max_seconds >= 10 )) || {
    fail 'K8S_ENDPOINT_DRAIN_TIMEOUT must be an integer of at least 10 seconds'; return 1;
  }
  max_attempts=$(((max_seconds + 1) / 2))
  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    if ! count="$(endpoint_ready_count "$name")"; then
      fail "EndpointSlice query or parser failed (see the preceding error); refusing to call it zero endpoints"
      return 1
    fi
    if (( count == 0 )); then
      info "Expected selector mismatch confirmed: zero ready EndpointSlice backends (poll $attempt/$max_attempts)"
      return 0
    fi
    if (( attempt == 1 || attempt % 5 == 0 )); then
      info "Waiting for selector change to clear EndpointSlice backends: count=$count (poll $attempt/$max_attempts)"
    fi
    (( attempt < max_attempts )) && sleep 2
  done
  # A final fresh sample covers a controller update at the poll boundary.
  if ! count="$(endpoint_ready_count "$name")"; then
    fail 'EndpointSlice query/parser failed at final check'; return 1
  fi
  if (( count == 0 )); then
    info 'Expected selector mismatch confirmed at final check: zero ready backends'
    return 0
  fi
  k get endpointslices -l "kubernetes.io/service-name=$name" -o wide || true
  fail "selector mismatch still has $count ready EndpointSlice backend(s) after about $max_seconds seconds"
}

# A ready EndpointSlice proves there are backends, but not necessarily that the
# node's Service data plane has finished programming its forwarding rules.
# Retry actual HTTP, keep failures visible, and fail after a bounded interval.
wait_service_http() {
  local url="$1" expected="${2:-alive}" max_attempts="${3:-45}"
  local attempt response="" last_error="" error_file
  [[ "$max_attempts" =~ ^[0-9]+$ ]] && (( max_attempts > 0 )) || {
    fail "invalid HTTP retry count: $max_attempts"; return 1;
  }
  error_file="$LOG_DIR/service-http-${CHAPTER}-${RUN_ID}.err"
  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    if response="$(app_get "$url" 2>"$error_file")"; then
      if [[ "$response" == *"$expected"* ]]; then
        info "Service HTTP succeeded on attempt $attempt/$max_attempts: $url"
        printf '%s\n' "$response"
        rm -f "$error_file"
        return 0
      fi
      last_error="unexpected HTTP response: $response"
    else
      # Preserve the most useful exception message without dumping tracebacks
      # on every expected transient connection attempt.
      last_error="$(tail -n 3 "$error_file" 2>/dev/null | tr '\n' ' ' || true)"
      [[ -n "$last_error" ]] || last_error='kubectl exec / HTTP request failed'
    fi
    if (( attempt == 1 || attempt % 5 == 0 || attempt == max_attempts )); then
      info "Service HTTP not yet verified (attempt $attempt/$max_attempts): ${last_error:0:300}"
    fi
    (( attempt < max_attempts )) && sleep 2
  done
  info "Persistent Service HTTP failure; collecting targeted network evidence"
  k get svc/flask-app -o wide || true
  k get endpointslices -l kubernetes.io/service-name=flask-app -o wide || true
  kubectl --context="$PROFILE" -n kube-system get pods -l k8s-app=kube-proxy -o wide || true
  fail "Service $url did not return expected [$expected] after $max_attempts attempts; last error: $last_error"
}

# Safe diagnostics plus deterministic container waiting reason checks for controlled faults.
wait_bad_pod() {
  local reason_re="$1" output
  for _ in $(seq 1 40); do
    output="$(k get pods -l app.kubernetes.io/name=flask-app -o json 2>/dev/null | \
      python3 -c 'import json,sys; d=json.load(sys.stdin); print(" ".join(c.get("state",{}).get("waiting",{}).get("reason","") for p in d.get("items",[]) for c in p.get("status",{}).get("containerStatuses",[])))' 2>/dev/null || true)"
    [[ "$output" =~ $reason_re ]] && { info "Expected failure observed: $output"; return 0; }
    sleep 2
  done
  k get pods -l app.kubernetes.io/name=flask-app -o wide
  fail "did not observe expected Pod waiting reason regex $reason_re"; return 1
}

restore_six() {
  step "Restore verified Chapter 6 configuration and networking"
  recover_canonical_configmap_owner "$PROFILE" default manifests/chapter-06/flask-config.yaml
  apply_owned "$PROFILE" default configmap/flask-config manifests/chapter-06/flask-config.yaml
  apply_owned "$PROFILE" default deployment/flask-app manifests/chapter-06/flask-deployment.yaml
  apply_owned "$PROFILE" default service/flask-app manifests/chapter-04/flask-service.yaml
  # Direct kubectl patch/set-image changes are not always reverted by kubectl apply
  # because they may not appear in the last-applied configuration. Explicitly
  # restore the exact fields that Chapters 4 and 8 deliberately disrupt.
  k patch service/flask-app --type=json -p '[{"op":"replace","path":"/spec/selector","value":{"app.kubernetes.io/name":"flask-app"}}]'
  k patch deployment/flask-app --type=strategic -p '{"spec":{"template":{"spec":{"containers":[{"name":"flask","image":"flask-app:v2.2.0","command":null,"readinessProbe":{"httpGet":{"path":"/readyz"}}}]}}}}'
  wait_rollout
  check_service_ready
  assert_app_value version v2.2.0
}

summary() { step "Final evidence"; info "Chapter $CHAPTER passed. Log: $LOG_FILE"; }
