#!/usr/bin/env bash
# Usage: bash validation/run.sh 01 02 03 ... ; default 01 through 09.
# Stop immediately on first failure. Re-run the failed chapter after correction.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
chapters=("$@")
if [[ "${#chapters[@]}" -eq 0 ]]; then chapters=(01 02 03 04 05 06 07 08 09); fi
for ch in "${chapters[@]}"; do
  case "$ch" in
    01) script=01-container.sh;;
    02) script=02-cluster-pod.sh;;
    03) script=03-deployments.sh;;
    04) script=04-services-dns.sh;;
    05) script=05-config-secrets.sh;;
    06) script=06-health-hpa.sh;;
    07) script=07-security.sh;;
    08) script=08-troubleshooting.sh;;
    09) script=09-helm.sh;;
    10) script=10-eks-preflight.sh;;
    11) script=11-eks-observe.sh;;
    12) script=12-capstone-inspect.sh;;
    *) echo "Unrecognised chapter: $ch" >&2; exit 2;;
  esac
  echo "===== RUN CHAPTER $ch ====="
  bash "validation/$script" || { rc=$?; echo "Validation stopped at Chapter $ch (exit $rc). Fix and resume with: bash validation/run.sh $ch" >&2; exit "$rc"; }
done
printf '\n===== ALL REQUESTED CHAPTERS COMPLETED =====\n'
