# Chapter 3 — Deploy, scale and recover applications

**Goal:** Let a Deployment manage replicas, perform a rolling update, and recover from a failed release. Start from Chapter 2's running Minikube cluster, without a leftover standalone `flask-app` Pod.

From the **repository root**:

```bash
kubectl config current-context
minikube image load flask-app:v1.0.0
kubectl apply -f manifests/chapter-03/flask-deployment.yaml
kubectl rollout status deployment/flask-app
kubectl get deployment,replicasets,pods
kubectl scale deployment/flask-app --replicas=3
kubectl get pods -l app.kubernetes.io/name=flask-app
```

Expected: Deployment `flask-app` has three Ready replicas. Delete one **specific lab-owned Pod** (replace the name with one you inspected); the Deployment should replace it:

```bash
kubectl get pods -l app.kubernetes.io/name=flask-app
kubectl delete pod POD_NAME
kubectl rollout status deployment/flask-app
```

**Failure exercise:** In a separate copy of the manifest, temporarily change the image tag to an unavailable version. Apply that copy, inspect `kubectl describe pod`, events and `kubectl rollout status`, and roll back using the revision history or reapply the original manifest. Never commit a deliberately broken manifest as the baseline.

```bash
kubectl rollout history deployment/flask-app
kubectl rollout undo deployment/flask-app
kubectl apply -f manifests/chapter-03/flask-deployment.yaml
kubectl rollout status deployment/flask-app
```

**Keep** the Deployment for Chapter 4. If Pods are missing, inspect label selectors, image availability and scheduling events before making changes.
