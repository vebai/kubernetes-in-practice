#!/usr/bin/env bash
set -Eeuo pipefail
CHAPTER=10
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/aws-lib.sh"
step 'EKS book configuration: no infrastructure creation'
[[ -f eks/cluster.yaml && -f eks/values-eks.yaml ]] || { fail 'EKS files missing'; exit 1; }
python3 - <<'PY'
from pathlib import Path
s=Path('eks/cluster.yaml').read_text()
for exact in ('name: flask-eks', 'region: eu-west-2', 'version: "1.36"', 'autoModeConfig:', 'enabled: true'):
    assert exact in s, f'Missing baseline: {exact}'
print('EKS configuration expected fields present (not a live AWS cluster proof).')
PY
step 'Lint and render the real EKS values with a harmless synthetic registry'
render_eks_values eks/values-eks.yaml "$LOG_DIR/eks-render-${RUN_ID}.yaml"
if [[ "$AWS_LIVE_READONLY" == 1 ]]; then
  step 'Optional read-only verification of existing AWS account, EKS cluster and ECR image'
  aws_eks_preflight
  aws ecr describe-images --repository-name "$ECR_REPOSITORY" --region "$AWS_REGION" \
    --image-ids imageTag="$IMAGE_TAG" --query 'imageDetails[].{digest:imageDigest,pushedAt:imagePushedAt}' --output table
  eks_digest="$(aws ecr describe-images --repository-name "$ECR_REPOSITORY" --region "$AWS_REGION" \
    --image-ids imageTag="$IMAGE_TAG" --query 'imageDetails[0].imageDigest' --output text)"
  [[ "$eks_digest" == sha256:* ]] || { fail 'ECR image digest was missing'; exit 1; }
else
  info 'EKS cluster creation and image push are NOT tested; these need a deliberate, chargeable AWS session.'
fi
summary
