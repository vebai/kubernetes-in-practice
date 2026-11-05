# EKS: identity, cost and change safety

The local chapters use Minikube. **Chapters 10–12 are opt-in AWS labs**. Creating an EKS cluster, Auto Mode compute, an Application Load Balancer, public IPv4 addresses, ECR storage and data transfer can generate charges. Even a cluster with no application Pods may incur an EKS cluster fee.

Before any AWS create or delete operation:

```bash
aws sts get-caller-identity
aws configure get region
kubectl config current-context
```

Use a dedicated learning AWS account, not a production account. Confirm `eu-west-2` or your chosen Region, check AWS service availability and account quotas, and create a billing budget. A budget **warns**; it does not automatically stop resources.

The example uses **EKS Auto Mode** through `eksctl`. Review `eks/cluster.yaml` and verify the Kubernetes version is currently supported before calling `eksctl create cluster -f eks/cluster.yaml`. Cluster provisioning is not performed by any repository validation script.

Keep your AWS CLI human identity and Kubernetes workload permissions separate. The tested live path restricts the public ALB ingress to an approved single public IPv4 `/32`; never assume a wildcard internet-facing ALB is restricted. An initially `DEGRADED` Metrics Server add-on can reflect pending node capacity; inspect health issues and give bounded time for recovery before making a change. ECR pushing, EKS cluster creation and deploying workloads require different authorised actions. Do not store permanent AWS keys in this repository.

An Ingress may provision an AWS load balancer. Delete the Helm release and verify AWS load balancers and target groups are removed **before** deleting the cluster. See [Safe cleanup](CLEANUP.md). A failed cluster deletion can leave billable resources; inspect rather than assuming it succeeded.
