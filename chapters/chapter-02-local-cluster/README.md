# Chapter 2 — Understand Kubernetes and create a local cluster

**Goal:** Create a Minikube cluster, verify the active context, load your Chapter 1 image and run a first Pod.

**Starting state:** The `flask-app:v1.0.0` image exists locally, and Docker, `kubectl` and Minikube are installed. Work from the **repository root**.

```bash
minikube start --driver=docker
kubectl config current-context
kubectl get nodes
minikube image load flask-app:v1.0.0
kubectl apply -f manifests/chapter-02/flask-pod.yaml
kubectl get pod flask-app -o wide
kubectl describe pod flask-app
```

Expected: current context is `minikube`, the node reports `Ready`, and the `flask-app` Pod eventually reports `Running`. If it fails, inspect events and check that the image is loaded into the **same** Minikube profile.

```bash
kubectl delete -f manifests/chapter-02/flask-pod.yaml
```

Remove this standalone Pod before Chapter 3, which introduces the Deployment that will own its Pods. **Do not delete the Minikube cluster or the local image.**
