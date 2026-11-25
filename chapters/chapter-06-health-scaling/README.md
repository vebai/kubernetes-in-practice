# Chapter 6 — Health probes, resources and scaling

**Goal:** Distinguish readiness, liveness and startup checks, set resource requests/limits and observe HPA behaviour. The application evolves across `v2.1.0` (readiness), `v2.2.0` (CPU work), and `v2.3.0` (hardened release).

**Starting state:** The Minikube profile and earlier Service exist. The following runnable configuration uses the Chapter 6 `v2.2.0` baseline. Run from the **repository root**:

Confirm that `kubectl` is targeting the same local Minikube profile you used in the earlier chapters. In the commands below, use that profile name (`minikube` or, for example, `k8s-chapter02`).

```bash
kubectl config current-context
```

After confirming the context is your local lab profile, run:

```bash
LAB_PROFILE="$(kubectl config current-context)"
minikube -p "$LAB_PROFILE" image build -t flask-app:v2.2.0 ./flask-app/versions/v2.2.0
```

> [!WARNING]
> Stop if the build fails. If `pip` shows `Temporary failure in name resolution` before reporting `No matching distribution found`, the builder could not reach the package index. Keep the pinned dependencies and try building with your host Docker engine, then load the image into the same Minikube profile.

```bash
docker build -t flask-app:v2.2.0 ./flask-app/versions/v2.2.0 &&
  minikube -p "$LAB_PROFILE" image load flask-app:v2.2.0
```

Before applying the manifests, confirm that the profile lists `flask-app:v2.2.0`:

```bash
minikube -p "$LAB_PROFILE" image ls
```

```bash
kubectl apply -f manifests/chapter-06/flask-config.yaml
kubectl apply -f manifests/chapter-06/flask-deployment.yaml
kubectl rollout status deployment/flask-app
kubectl get pods -l app.kubernetes.io/name=flask-app
```

The Deployment contains startup, readiness and liveness probes plus CPU and memory requests/limits. If a Pod is initially not Ready, inspect the startup delay rather than increasing all probe thresholds blindly.

If the Deployment was already applied and a Pod shows `ErrImageNeverPull`, confirm the image is present in the correct profile. If the rollout has exceeded its progress deadline, restart it after loading the image:

```bash
kubectl rollout restart deployment/flask-app
kubectl rollout status deployment/flask-app --timeout=150s
```

## Enable Metrics Server for CPU-based scaling

If `kubectl top pods` reports `Metrics API not available`, enable the Metrics Server add-on in your local lab profile. Confirm the active context is your Minikube profile before running these commands:

```bash
LAB_PROFILE="$(kubectl config current-context)"
minikube -p "$LAB_PROFILE" addons enable metrics-server
kubectl --context="$LAB_PROFILE" -n kube-system rollout status deployment/metrics-server --timeout=180s
kubectl --context="$LAB_PROFILE" wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=120s
kubectl --context="$LAB_PROFILE" top pods
```

After the Metrics API becomes available, wait briefly for the first sample if `kubectl top pods` still has no data. If the rollout or API wait times out, inspect the add-on and API service:

```bash
kubectl --context="$LAB_PROFILE" -n kube-system describe deployment metrics-server
kubectl --context="$LAB_PROFILE" describe apiservice v1beta1.metrics.k8s.io
```

Once `kubectl top pods` shows CPU and memory for the Flask Pods, apply the HPA:

```bash
kubectl apply -f manifests/chapter-06/hpa.yaml
kubectl get hpa flask-app
```

**Evidence:** inspect Pod readiness, rollout status, CPU utilisation and HPA desired replicas. Load generators consume resources; run only the controlled load exercise in the book on your own cluster and stop it afterwards.

**Cleanup:** Remove only the lab's HPA when finished: `kubectl delete -f manifests/chapter-06/hpa.yaml`. Keep your cluster and service for later exercises.
