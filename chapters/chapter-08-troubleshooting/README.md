# Chapter 8 — Troubleshoot Kubernetes without guessing

**Goal:** Use the evidence path to investigate `Pending`, image failures, `CrashLoopBackOff`, configuration errors, readiness failures and Service selector mismatches.

Use the original local Minikube profile with the Chapter 6 Deployment and Chapter 4 Service in the `default` namespace. From the repository root, **first check the context**:

```bash
kubectl config current-context
kubectl config get-contexts
```

> [!WARNING]
> If you completed Chapter 7, your active context may still be `security-lab`. Its Flask Deployment lives in the `shop` namespace. A `NotFound` error in `default` on that cluster means you are looking in the wrong cluster and namespace for this exercise. Switch back to the profile you used in Chapter 6 before diagnosing failures or restoring manifests.

Set the context for the lab. Replace `minikube` with your profile name if you used a different one, such as `k8s-chapter02`:

```bash
LAB_CONTEXT=minikube
kubectl --context="$LAB_CONTEXT" --namespace=default get deployment/flask-app service/flask-app
```

Proceed once both resources are found. Use the same context and namespace for diagnosis and recovery:

```bash
kubectl --context="$LAB_CONTEXT" --namespace=default get nodes
kubectl --context="$LAB_CONTEXT" --namespace=default get deployment,service,pods
kubectl --context="$LAB_CONTEXT" --namespace=default get events --sort-by=.lastTimestamp
kubectl --context="$LAB_CONTEXT" --namespace=default rollout status deployment/flask-app
kubectl --context="$LAB_CONTEXT" --namespace=default logs deployment/flask-app --tail=50
kubectl --context="$LAB_CONTEXT" --namespace=default get endpointslices -l kubernetes.io/service-name=flask-app
```

**Five controlled failures to practise:** change an image to an unavailable tag; remove a referenced ConfigMap; specify an invalid readiness path; mismatch a Service selector; or make a container command exit unexpectedly. Introduce **one at a time** in a disposable copy. Before repairing, capture the Pod conditions, events, rollout status, container state and logs.

After each exercise, restore the previously working manifests from [`manifests/chapter-06/`](../../manifests/chapter-06/) and [`manifests/chapter-04/`](../../manifests/chapter-04/):

```bash
kubectl --context="$LAB_CONTEXT" --namespace=default apply -f manifests/chapter-06/flask-config.yaml
kubectl --context="$LAB_CONTEXT" --namespace=default apply -f manifests/chapter-06/flask-deployment.yaml
kubectl --context="$LAB_CONTEXT" --namespace=default apply -f manifests/chapter-04/flask-service.yaml
kubectl --context="$LAB_CONTEXT" --namespace=default rollout status deployment/flask-app
```

**Proof of recovery:** the Deployment becomes Available, EndpointSlices contain ready endpoints and a port-forwarded `/healthz` request succeeds. Use [the short diagnostic reference](../../docs/TROUBLESHOOTING.md) when symptoms are ambiguous.
