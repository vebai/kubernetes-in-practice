# Chapter 8 — Troubleshoot Kubernetes without guessing

**Goal:** Use the evidence path to investigate `Pending`, image failures, `CrashLoopBackOff`, configuration errors, readiness failures and Service selector mismatches.

Use a cluster containing the Chapter 6 Deployment and Service. From the repository root, **first check the context**:

```bash
kubectl config current-context
kubectl get nodes
kubectl get deployment,service,pods
kubectl get events --sort-by=.lastTimestamp
kubectl rollout status deployment/flask-app
kubectl logs deployment/flask-app --tail=50
kubectl get endpointslices -l kubernetes.io/service-name=flask-app
```

**Five controlled failures to practise:** change an image to an unavailable tag; remove a referenced ConfigMap; specify an invalid readiness path; mismatch a Service selector; or make a container command exit unexpectedly. Introduce **one at a time** in a disposable copy. Before repairing, capture the Pod conditions, events, rollout status, container state and logs.

After each exercise, restore the previously working manifests from [`manifests/chapter-06/`](../../manifests/chapter-06/) and [`manifests/chapter-04/`](../../manifests/chapter-04/):

```bash
kubectl apply -f manifests/chapter-06/flask-config.yaml
kubectl apply -f manifests/chapter-06/flask-deployment.yaml
kubectl apply -f manifests/chapter-04/flask-service.yaml
kubectl rollout status deployment/flask-app
```

**Proof of recovery:** the Deployment becomes Available, EndpointSlices contain ready endpoints and a port-forwarded `/healthz` request succeeds. Use [the short diagnostic reference](../../docs/TROUBLESHOOTING.md) when symptoms are ambiguous.
