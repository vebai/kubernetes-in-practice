# Chapter 2 — Understand Kubernetes and create a local cluster

**Goal:** Create a Minikube cluster, verify the active context, load your Chapter 1 image and run a first Pod.

**Starting state:** The `flask-app:v1.0.0` image exists locally, and Docker, `kubectl` and Minikube are installed. Work from the **repository root**.

```bash
minikube start --driver=docker
kubectl config current-context
kubectl get nodes
```

Confirm that the context is `minikube` and the node is `Ready` before loading the image.

> [!WARNING]
> Stop if `minikube start` fails or `kubectl get nodes` reports `connection refused`. The Kubernetes API is unreachable, so Pod inspection, deployment and cleanup cannot proceed. If startup reports `GUEST_CERT`, expired kubeadm certificates and an old kubeadm configuration API such as `kubeadm.k8s.io/v1beta2`, use the recovery steps below.

### Recover from expired certificates on an older profile

Start a separate local profile so the existing cluster and its data are preserved. If `k8s-chapter02` is already in use for another lab, choose an unused name and substitute it throughout.

```bash
minikube start -p k8s-chapter02 --driver=docker --keep-context
kubectl --context=k8s-chapter02 wait --for=condition=Ready node --all --timeout=120s
kubectl --context=k8s-chapter02 get nodes
```

Once the node is `Ready`, run `kubectl config use-context k8s-chapter02` and confirm it with `kubectl config current-context`. In the block below, use `minikube -p k8s-chapter02 image load flask-app:v1.0.0` for the image-loading command. Use the same profile for later Minikube commands in this lab.

### Run the Flask Pod

```bash
minikube image load flask-app:v1.0.0
kubectl apply -f manifests/chapter-02/flask-pod.yaml
kubectl get pod flask-app -o wide
kubectl describe pod flask-app
```

Expected: the `flask-app` Pod eventually reports `Running` in the selected lab context. If it fails, inspect events and check that the image is loaded into the **same** Minikube profile.

```bash
kubectl delete -f manifests/chapter-02/flask-pod.yaml
```

Confirm you are still using the same lab context before running cleanup. Remove this standalone Pod before Chapter 3, which introduces the Deployment that will own its Pods. **Do not delete the Minikube cluster or the local image.**
