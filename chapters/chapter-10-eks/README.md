# Chapter 10 — Deploy to Amazon EKS (optional AWS lab)

**Goal:** Publish the known-good image to Amazon ECR, create an EKS Auto Mode cluster and deploy the Helm release through an Application Load Balancer.

**This lab costs money.** It is not required for Chapters 1–9. Before proceeding, read [EKS safety and costs](../../docs/EKS-SAFETY.md). You need AWS CLI v2, `eksctl`, Docker, Helm and `kubectl`, plus appropriate permissions in a **non-production** AWS account.

From the **repository root**, verify identity first:

```bash
export AWS_REGION=eu-west-2
export AWS_DEFAULT_REGION="$AWS_REGION"
export CLUSTER_NAME=flask-eks
export ECR_REPOSITORY=flask-app
export IMAGE_TAG=v2.3.0
aws sts get-caller-identity
aws eks describe-cluster-versions --region "$AWS_REGION" --query 'clusterVersions[].clusterVersion' --output text
```

**Before creating resources:** inspect [`eks/cluster.yaml`](../../eks/cluster.yaml), confirm `flask-eks`, `eu-west-2` and the supported Kubernetes version. If your account already has a repository or cluster with that name, do not recreate it blindly. The next create commands are **opt-in** and may incur charges:

```bash
aws ecr create-repository --repository-name "$ECR_REPOSITORY" --image-tag-mutability IMMUTABLE
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker build --platform linux/amd64 -t "${ECR_REGISTRY}/flask-app:${IMAGE_TAG}" ./flask-app/versions/v2.3.0
docker push "${ECR_REGISTRY}/flask-app:${IMAGE_TAG}"
```

Edit your *local copy* of [`eks/values-eks.yaml`](../../eks/values-eks.yaml): replace `REPLACE_WITH_ECR_REGISTRY` with `$ECR_REGISTRY`'s **actual value**. Never commit an account-specific credential or token. Only when the AWS version, account, Region, quotas and budget are confirmed:

```bash
eksctl create cluster -f eks/cluster.yaml
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" --alias "$CLUSTER_NAME"
kubectl config current-context
kubectl get nodes
kubectl apply -f eks/alb-ingress-class-params.yaml
kubectl apply -f eks/alb-ingress-class.yaml
kubectl create namespace flask --dry-run=client -o yaml | kubectl apply -f -
helm lint helm/flask-app -f eks/values-eks.yaml
helm upgrade --install flask-app helm/flask-app -n flask -f eks/values-eks.yaml --wait --timeout 10m
kubectl get deployment,pods,service,ingress -n flask
```

EKS Auto Mode capacity and Metrics Server availability may require additional checks described in the book. Verify the application's external HTTP path, the ALB state, target health and HPA; an Ingress object alone is not proof that traffic works.

**Cleanup is a separate, required step:** uninstall the Helm release, verify load balancers have gone, delete cluster resources only after confirmation, and inspect ECR. Follow [the EKS cleanup sequence](../../docs/CLEANUP.md).
