#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
step 'AWS preflight — READ ONLY: no AWS or Kubernetes mutation'
check_files; check_region
for tool in aws eksctl docker kubectl helm python3; do need "$tool"; done
aws --version; eksctl version
[[ "$(aws --version 2>&1)" == aws-cli/2.* ]] || stop 'AWS CLI v2 is required for the EKS live evaluation'
# EKS Auto Mode needs eksctl >=0.195.0; refuse older versions.
python3 - "$(eksctl version)" <<'PYVERS' || stop 'eksctl is too old for EKS Auto Mode (need >= 0.215.0)'
import re, sys
v = re.search(r'(\d+)\.(\d+)\.(\d+)', sys.argv[1])
assert v and tuple(map(int, v.groups())) >= (0, 215, 0)
print('eksctl Auto Mode version: compatible')
PYVERS
kubectl version --client; helm version --short; docker version --format 'Docker Engine {{.Server.Version}}'
step 'Active AWS identity — confirm this is a NON-PRODUCTION account'
awsx sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output json
ACTUAL_ACCOUNT="$(awsx sts get-caller-identity --query Account --output text)"
info 'Write down and independently verify the AWS account above; use K8S_EXPECTED_AWS_ACCOUNT in all later scripts.'
info 'For the public ALB, determine YOUR public IPv4 egress address and use K8S_ALLOWED_CIDR=IP/32 for the paid deployment.'
info 'The EKS Auto Mode IngressClassParams will restrict inbound ALB access to that /32; no 0.0.0.0/0 allowed.'
step 'Check Region availability and book Kubernetes 1.36 support'
zones="$(awsx ec2 describe-availability-zones --filters Name=state,Values=available --query 'AvailabilityZones[].ZoneName' --output text)" || stop 'Cannot inspect available AWS availability zones'
printf 'Available AZs: %s\n' "$zones"
[[ "$(printf '%s\n' "$zones" | wc -w | tr -d ' ')" -ge 2 ]] || stop 'Need at least two available Availability Zones for ALB and resilient workload tests'
if ! versions="$(awsx eks describe-cluster-versions --query 'clusterVersions[].clusterVersion' --output text)"; then
  stop 'Unable to query EKS versions; check AWS CLI version/permissions before incurring charges'
fi
printf 'EKS versions: %s\n' "$versions"
has_token "$versions" 1.36 || stop 'EKS version 1.36 not offered in eu-west-2; do not create the book cluster until reconciled'
step 'Inventory existing AWS EKS clusters and ECR repositories'
clusters="$(awsx eks list-clusters --query 'clusters[]' --output text)" || stop 'Cannot list EKS clusters'
printf 'EKS clusters in %s: %s\n' "$AWS_REGION" "${clusters:-none}"
if has_token "$clusters" flask-eks; then
  info 'BLOCKER: flask-eks already exists. Do NOT create another cluster or run the create script; inspect ownership first.'
fi
repos="$(awsx ecr describe-repositories --query 'repositories[].repositoryName' --output text)" || stop 'Cannot list ECR repositories'
printf 'ECR repos in %s: %s\n' "$AWS_REGION" "${repos:-none}"
if has_token "$repos" flask-app; then info 'Existing flask-app ECR repository detected; the Chapter 10 script will refuse to overwrite it.'; fi
step 'Check existing metrics-server add-on support for this version'
if ! awsx eks describe-addon-versions --addon-name metrics-server --kubernetes-version 1.36 \
  --query 'addons[0].addonVersions[0].addonVersion' --output text; then
  info 'Metrics Server add-on query unavailable. Investigate before testing Chapter 11 HPA.'
fi
step 'Attempt read-only EKS quota inventory; verify EC2 quotas separately in Service Quotas console'
if ! awsx service-quotas list-service-quotas --service-code eks --query 'Quotas[].{Quota:QuotaName,Value:Value}' --output table; then
  info 'Service Quotas read denied or unavailable; inspect EKS and EC2 quotas in AWS Console before deployment.'
fi
step 'AWS billing and IAM must be checked before authorising deployment'
info 'Confirm AWS Budgets alert, estimated EKS control-plane + Auto Mode EC2 + ALB + NAT (if created) + public IPv4 + ECR charges.'
info 'Confirm permissions for CloudFormation, EKS, IAM role creation/pass-role, EC2 networking, ECR, ELB and add-ons.'
info 'A budget alert does NOT cap or automatically stop spending.'
info "PRECHECK COMPLETE (READ ONLY). Log: $LOG_FILE"
