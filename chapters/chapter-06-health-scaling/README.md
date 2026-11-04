# Chapter 6 — Health probes, resources and scaling

**Goal:** Distinguish readiness, liveness and startup checks, set resource requests/limits and observe HPA behaviour. The application evolves across `v2.1.0` (readiness), `v2.2.0` (CPU work), and `v2.3.0` (hardened release).

**Starting state:** The Minikube profile and earlier Service exist. The following runnable configuration uses the Chapter 6 `v2.2.0` baseline. Run from the **repository root**:

```bash
minikube image build -t flask-app:v2.2.0 ./flask-app/versions/v2.2.0
kubectl apply -f manifests/chapter-06/flask-config.yaml
kubectl apply -f manifests/chapter-06/flask-deployment.yaml
kubectl rollout status deployment/flask-app
kubectl get pods -l app.kubernetes.io/name=flask-app
```

The Deployment contains startup, readiness and liveness probes plus CPU and memory requests/limits. If a Pod is initially not Ready, inspect the startup delay rather than increasing all probe thresholds blindly.

For CPU-based horizontal scaling, your cluster needs Metrics Server. Verify it first:

```bash
kubectl top pods
```

If metrics are unavailable, consult the Minikube documentation for the matching Metrics Server add-on. Once metrics work:

```bash
kubectl apply -f manifests/chapter-06/hpa.yaml
kubectl get hpa flask-app
```

**Evidence:** inspect Pod readiness, rollout status, CPU utilisation and HPA desired replicas. Load generators consume resources; run only the controlled load exercise in the book on your own cluster and stop it afterwards.

**Cleanup:** Remove only the lab's HPA when finished: `kubectl delete -f manifests/chapter-06/hpa.yaml`. Keep your cluster and service for later exercises.
