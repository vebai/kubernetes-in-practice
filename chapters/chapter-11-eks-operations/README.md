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
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top pods -n flask
```

If `kubectl top pods` reports `Metrics API not available`, use the [Chapter 10 Metrics Server guide](../chapter-10-eks/README.md#enable-metrics-server-on-eks) to check the installation before scheduling any changes.

The presence of an add-on or Kubernetes resource alone does not prove it is correctly configured. Investigate warnings and service behaviour before applying any updates. See [Troubleshooting](../../docs/TROUBLESHOOTING.md).

**Cleanup:** no resources are created by this read-only checklist; keep the same cluster for Chapter 12 if you intend to finish the final project.


## Verify operational behaviour

Confirm target-group health, external HTTP responses, metrics and HPA conditions in the environment you control. Check Pod placement with `kubectl get pods -n flask -o wide`: Ready nodes across multiple Availability Zones do not prove the application Pods are distributed across those nodes.

For optional read-only AWS inspection, run `bash validation/aws-live/11-observe.sh` from the repository root after following [the AWS validation guide](../../validation/aws-live/README.md). This requires an exact AWS account and a verified Kubernetes context.
