#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tests/check_repo.py
if command -v helm >/dev/null 2>&1; then
  helm lint helm/flask-app -f helm/values-development.yaml
  helm template flask-app helm/flask-app --namespace flask -f helm/values-development.yaml >/dev/null
  echo 'Helm lint and template: passed'
else
  echo 'Helm not installed: skipped chart rendering (syntax needs Helm CLI verification).'
fi
