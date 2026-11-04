# Chapter 11 — Operate EKS safely

**Goal:** Inspect application and platform health, permissions, add-ons, storage requirements and operational evidence on an EKS cluster you already control.

**Prerequisites:** the optional Chapter 10 EKS exercise is running. These commands are **read-only**; they do not create or remove infrastructure. Check the AWS account and target cluster first:

```bash
aws sts get-caller-identity
kubectl config current-context
kubectl get nodes -L topology.kubernetes.io/zone
kubectl get deployment,pods,service,ingress,hpa,pdb -n flask
kubectl get events -n flask --sort-by=.lastTimestamp
kubectl logs deployment/flask-app -n flask --tail=40
helm status flask-app -n flask
```

**Decisions to investigate:** Does the current identity have the intended access? Are Pods schedulable and Ready? Can the load balancer reach a healthy backend? Is the HPA receiving metrics? Does your EKS Auto Mode CNI and policy configuration support the network isolation you intend to use?

```bash
aws eks list-addons --cluster-name flask-eks --region eu-west-2
kubectl get ingressclass
kubectl get storageclass
kubectl top pods -n flask
```

The presence of an add-on or Kubernetes resource alone does not prove it is correctly configured. Investigate warnings and service behaviour before applying any updates. See [Troubleshooting](../../docs/TROUBLESHOOTING.md).

**Cleanup:** no resources are created by this read-only checklist; keep the same cluster for Chapter 12 if you intend to finish the final project.
