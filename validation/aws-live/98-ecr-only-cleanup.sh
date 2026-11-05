#!/usr/bin/env bash
# Opt-in ECR removal when EKS creation failed BEFORE any cluster existed.
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
step 'Partial-run cleanup: delete only lab-created ECR repo when no book EKS cluster exists'
need_yes K8S_AWS_DELETE_ECR_ONLY "${K8S_AWS_DELETE_ECR_ONLY:-}" DELETE_BOOK_ECR_ONLY
check_account
[[ -f "$STATE_DIR/ecr-created.account" ]] || stop 'No lab ECR ownership marker'
[[ "$(cat "$STATE_DIR/ecr-created.account")" == "$ACTUAL_ACCOUNT" ]] || stop 'ECR ownership account mismatch'
clusters="$(awsx eks list-clusters --query 'clusters[]' --output text)"
! has_token "$clusters" flask-eks || stop 'flask-eks still exists; do not remove its ECR image before recovering or deleting cluster'
awsx ecr describe-images --repository-name "$ECR_REPOSITORY" --query 'imageDetails[].imageTags' --output json > "$STATE_DIR/ecr-tags-before-partial-cleanup.json"
python3 - "$STATE_DIR/ecr-tags-before-partial-cleanup.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert all(set(v or []) <= {'v2.3.0'} for v in x), 'Unexpected image tags: refusing ECR deletion'
PY
awsx ecr delete-repository --repository-name "$ECR_REPOSITORY" --force --query repository.repositoryName --output text
info 'Lab-created ECR repo removed. Inspect CloudFormation, NAT, ALB, EKS and billing for any partial resources.'
