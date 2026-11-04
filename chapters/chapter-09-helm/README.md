# Chapter 9 — Package and release the application with Helm

**Goal:** Use one chart for repeatable releases, validate it before installation and understand environment-specific values.

Start with a running Minikube cluster. From the repository root:

```bash
minikube image build -t flask-app:v2.3.0 ./flask-app/versions/v2.3.0
helm lint helm/flask-app -f helm/values-development.yaml
helm template flask-app helm/flask-app -n flask -f helm/values-development.yaml > /tmp/flask-rendered.yaml
kubectl create namespace flask --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install flask-app helm/flask-app -n flask -f helm/values-development.yaml --wait --timeout 5m
helm status flask-app -n flask
kubectl get deployment,service,pods -n flask
```

Expected: a rendered Deployment, Service and ConfigMap; a healthy Helm release; one Ready application replica in the `flask` namespace. Confirm the image exists inside the active Minikube profile if Pods report image errors.

The same chart also contains disabled-by-default optional HPA, Ingress and PDB templates. Production-like values require compatible cluster capabilities and a reachable image; do not apply [`values-production.yaml`](../../helm/values-production.yaml) blindly on a local cluster.

**Cleanup:**

```bash
helm uninstall flask-app -n flask
```

Only delete the `flask` namespace after verifying nothing else uses it. Keep the Helm chart and local application image for later work.
