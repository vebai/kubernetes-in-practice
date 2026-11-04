# EKS example files — optional, chargeable AWS labs

Before creating anything, read [EKS safety and costs](../docs/EKS-SAFETY.md) and the [Chapter 10 guide](../chapters/chapter-10-eks/README.md).

The files here are **examples**, not a deployment script:

- `cluster.yaml` — `eksctl` cluster configuration with EKS Auto Mode; check the **currently supported Kubernetes version** and your AWS Region before use.
- `alb-ingress-class-params.yaml` and `alb-ingress-class.yaml` — Application Load Balancer IngressClass resources.
- `values-eks.yaml` — Helm values for the EKS release.
- `values-capstone.yaml` — more demanding release settings for the capstone.

Replace the `REPLACE_WITH_ECR_REGISTRY` image repository in the values file with your own verified ECR registry address. Do not push credentials or kubeconfig files to GitHub. Creating an Ingress may create a chargeable AWS ALB.

**Execution boundary:** Use an authorised, non-production AWS account; verify `aws sts get-caller-identity` and `kubectl config current-context` before deploying or deleting. No automated script in this repository creates an EKS cluster.
