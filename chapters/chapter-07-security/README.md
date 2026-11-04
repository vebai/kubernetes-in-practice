# Chapter 7 — Secure a Kubernetes workload

**Goal:** Practise restricted Pods, namespace-scoped RBAC and NetworkPolicy without touching your earlier Minikube environment. This uses a **separate** profile named `security-lab`.

**Prerequisites:** Docker, Minikube, kubectl and a supported CNI with NetworkPolicy enforcement. Check whether your Minikube version supports the book's Kubernetes version before specifying it. From the repository root:

```bash
minikube start -p security-lab --driver=docker --cni=calico
kubectl config use-context security-lab
kubectl apply -f manifests/chapter-07/namespace.yaml
kubectl apply -f manifests/chapter-07/flask-config.yaml
kubectl apply -f manifests/chapter-07/rbac.yaml
minikube image build -p security-lab -t flask-app:v2.3.0 ./flask-app/versions/v2.3.0
kubectl apply -f manifests/chapter-07/deployment-secure.yaml
kubectl apply -f manifests/chapter-07/service.yaml
kubectl rollout status deployment/flask-app -n shop
```

**Verify permissions and runtime identity:**

```bash
kubectl auth can-i get configmap/flask-config -n shop --as system:serviceaccount:shop:config-reader
kubectl auth can-i get secrets -n shop --as system:serviceaccount:shop:config-reader
kubectl exec -n shop deployment/flask-app -- id
```

Expected RBAC responses: `yes` for the named ConfigMap and `no` for Secrets (an administrator may need impersonation permissions to perform these tests).

**NetworkPolicy exercise:** create both test clients, then apply the default-deny rule and narrowly scoped allow rule. Verify the labelled `allowed-client` can contact `flask-app:80` and `denied-client` cannot. **Policies only work if the CNI enforces them**; a successful YAML apply alone proves nothing.

```bash
kubectl apply -f manifests/chapter-07/test-client-allowed.yaml
kubectl apply -f manifests/chapter-07/test-client-denied.yaml
kubectl apply -f manifests/chapter-07/default-deny-ingress.yaml
kubectl apply -f manifests/chapter-07/allow-frontend.yaml
kubectl get networkpolicy -n shop
```

**Cleanup:** After verifying no other workloads use this profile, run `minikube delete -p security-lab`. Then return to your original `minikube` context before continuing.
