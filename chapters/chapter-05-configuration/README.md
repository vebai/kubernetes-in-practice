# Chapter 5 — Configure applications and handle secrets

**Goal:** Separate runtime settings from container images. Start with the existing Minikube Deployment and Service from Chapters 3–4.

```bash
kubectl config current-context
kubectl apply -f manifests/chapter-05/flask-config.yaml
kubectl get configmap flask-config -o yaml
```

The sample ConfigMap supplies `APP_MESSAGE`. The ready-to-use file `manifests/chapter-05/flask-deployment-configured.yaml` references its `APP_MESSAGE` key. You can inspect this exact environment variable in that manifest:

```yaml
- name: APP_MESSAGE
  valueFrom:
    configMapKeyRef:
      name: flask-config
      key: APP_MESSAGE
```

Apply the configured Deployment and verify its rollout:

```bash
kubectl apply -f manifests/chapter-05/flask-deployment-configured.yaml
kubectl rollout status deployment/flask-app
```

For a local-only training secret, create a disposable Secret without committing the token:

```bash
kubectl create secret generic flask-secret --from-literal=API_TOKEN='training-only-token'
kubectl describe secret flask-secret
```

You can reference `API_TOKEN` using `valueFrom.secretKeyRef` as shown in the book. Never print or commit real secret contents. A Secret object is not automatically encrypted end-to-end merely because it is called a Secret.

**Failure exercise:** Remove or rename a ConfigMap key in your lab copy, observe the Pod events, then restore it and reverify the rollout.

**Cleanup:** When the secret exercise is finished, `kubectl delete secret flask-secret`; keep `flask-config` if you continue to Chapter 6.
