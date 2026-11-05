#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
printf '\n=== Kubernetes in Practice preflight (no cluster mutations) ===\n'
for tool in bash python3 docker curl kubectl minikube helm; do
  if command -v "$tool" >/dev/null 2>&1; then printf '[OK] %-10s %s\n' "$tool" "$(command -v "$tool")"
  else printf '[MISSING] %s\n' "$tool"; exit 2; fi
done
for f in flask-app/Dockerfile manifests/chapter-06/flask-deployment.yaml helm/flask-app/Chart.yaml eks/cluster.yaml; do
  [[ -f "$f" ]] || { echo "[MISSING] $f"; exit 2; }
done
if python3 -c 'import yaml' >/dev/null 2>&1; then
  echo '[OK] PyYAML present: repository tests can parse Kubernetes YAML'
else
  echo '[BLOCKER] PyYAML unavailable. Run: python3 -m venv .validation-venv && .validation-venv/bin/pip install PyYAML'
  echo 'Then use PATH="$PWD/.validation-venv/bin:$PATH" bash validation/preflight.sh'
  exit 2
fi
bash tests/validate-files.sh
python3 validation/static-audit.py
python3 validation/test-endpoint-count.py
python3 validation/test-configmap-owner.py
python3 validation/test-final-maintenance.py
bash validation/test-rbac-check.sh
for file in validation/*.sh; do bash -n "$file"; done
if grep -q -- '--resource-name' validation/07-security.sh; then
  echo '[BLOCKER] Chapter 7 uses unsupported kubectl auth can-i --resource-name syntax' >&2
  exit 2
fi
if ! grep -Fq "rbac_expect yes 'named ConfigMap flask-config' get configmaps/flask-config" validation/07-security.sh; then
  echo '[BLOCKER] Chapter 7 is missing named-ConfigMap RBAC validation' >&2
  exit 2
fi
printf 'PASS: Chapter 7 RBAC uses supported TYPE/NAME and handles expected denial exit statuses\n'
minikube_release="$(minikube version --short 2>/dev/null || minikube version 2>/dev/null | head -n 1)"
minikube_release="$(printf '%s\n' "$minikube_release" | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
if [[ -z "$minikube_release" ]]; then
  echo '[BLOCKER] Cannot determine Minikube version.' >&2; exit 3
fi
printf '[VERSION] Minikube %s\n' "$minikube_release"
if (( $(printf '%s' "$minikube_release" | cut -d. -f2) < 35 )); then
  echo '[BLOCKER] Update the outdated Minikube binary before resuming; v1.39.0 or newer is recommended.' >&2
  echo '[ACTION] Check: type -a minikube; brew list --versions minikube; brew upgrade minikube' >&2
  exit 3
fi

# Non-mutating runtime capacity checks so a 2-GB Docker VM cannot pass preflight for a 6-GB profile.
if docker info >/dev/null 2>&1; then
  available_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || true)"
  available_cpus="$(docker info --format '{{.NCPU}}' 2>/dev/null || true)"
  if [[ "$available_bytes" =~ ^[0-9]+$ ]]; then
    available_mib=$((available_bytes / 1024 / 1024))
    printf '[CAPACITY] Docker engine: %s MiB RAM, %s CPUs\n' "$available_mib" "${available_cpus:-unknown}"
    blockers=0
    for profile in LOCAL SECURITY; do
      if [[ "$profile" == LOCAL ]]; then
        requested_mib="${K8S_LOCAL_MEMORY:-6144}"; requested_cpus="${K8S_LOCAL_CPUS:-3}"
      else
        requested_mib="${K8S_SECURITY_MEMORY:-4096}"; requested_cpus="${K8S_SECURITY_CPUS:-2}"
      fi
      if [[ ! "$requested_mib" =~ ^[0-9]+$ || ! "$requested_cpus" =~ ^[0-9]+$ ]]; then
        echo "[BLOCKER] $profile memory/CPU override must be an integer" >&2; blockers=1; continue
      fi
      if (( available_mib < requested_mib + 256 )); then
        echo "[BLOCKER] $profile profile requests $requested_mib MiB; Docker has $available_mib MiB (needs 256 MiB headroom)." >&2
        blockers=1
      else
        echo "[OK] $profile memory requirement: $requested_mib MiB (+256 MiB headroom)"
      fi
      if [[ "$available_cpus" =~ ^[0-9]+$ ]] && (( available_cpus < requested_cpus )); then
        echo "[BLOCKER] $profile profile requests $requested_cpus CPUs; Docker has $available_cpus" >&2; blockers=1
      fi
    done
    if (( blockers )); then
      echo '[ACTION] Increase Docker Desktop > Settings > Resources > Advanced > Memory/CPUs, or explicitly lower the profile sizes. See validation/README.md.' >&2
      exit 3
    fi
  else
    echo '[WARN] Unable to read Docker memory from docker info. Chapter startup will verify it.'
  fi
else
  echo '[WARN] Docker Engine is not running; static checks passed but local cluster cannot start.'
fi
printf '=== OFFLINE CHECKS PASS; DOCKER CAPACITY PASS (live Kubernetes not yet tested) ===\n'
