# Safe cleanup by environment

**Identify the active cluster before removing anything:**

```bash
kubectl config current-context
kubectl get namespaces
```

## Local Docker image/container

```bash
docker ps -a --filter name=flask-app
docker rm -f flask-app   # only if this is your lab container
```

Keep image versions used by subsequent chapters. Do not run `docker system prune -a --volumes` on a shared machine.

## Local Minikube exercises

From the correct local context, inspect what you own before removing:

```bash
kubectl config current-context
kubectl get deployments,services,configmaps,hpa
```

If the lab has finished and no other workloads use the cluster, you may remove **only the lab-created resources** or intentionally delete the dedicated cluster profile:

```bash
minikube delete -p book-k8s-security
```

This removes the **dedicated** Chapter 7 profile. The book's separate hand-built lab may instead use `security-lab`; delete only the profile you actually created. The automated suite also uses `book-k8s-validation` for its main local profile. For the main Minikube profile, `minikube delete` removes the entire local cluster; verify it contains no other work before running.

## Helm (local or EKS)

```bash
helm list -A
helm uninstall flask-app -n flask
```

Run Helm uninstallation only if that release and namespace belong to your exercise. The namespace may remain; examine it separately. The release may be named differently in a local exercise.

## AWS EKS (cost-sensitive)

1. Confirm your AWS account, Region and Kubernetes context. Inspect the deployed Helm release, Ingress and load balancer.
2. Uninstall the lab Helm release and **verify that AWS-created ALBs, target groups and security groups have gone**.
3. Remove lab-created IngressClass and IngressClassParams objects only when nothing else uses them.
4. Review `eks/cluster.yaml`, confirm the intended cluster name and Region, and *then* run `eksctl delete cluster -f eks/cluster.yaml --wait` if you have explicitly chosen to destroy it.
5. Verify cluster deletion in EKS and inspect EC2 networking, ECR images, CloudWatch logs and remaining billable resources. Remove the lab ECR repository separately after confirming its images are no longer needed.

Deleting a Kubernetes workload does not automatically mean the cluster, ECR repository or every load balancer has been deleted. The author independently checked EKS, ECR, ELBv2 and CloudFormation after the November 2026 lab, but also recommends reviewing NAT gateways, EC2 instances, elastic IPs, ENIs, VPCs and delayed billing before declaring costs finished. Do not use blanket deletion commands on other people's resources.
