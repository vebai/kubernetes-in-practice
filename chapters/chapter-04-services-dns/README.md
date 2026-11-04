# Chapter 4 — Services, DNS and the request path

**Goal:** Give the Chapter 3 Deployment a stable ClusterIP Service, verify backends through EndpointSlices and isolate a selector mismatch.

Run from the **repository root** with context `minikube`:

```bash
kubectl get deployment flask-app
kubectl apply -f manifests/chapter-04/flask-service.yaml
kubectl get service flask-app
kubectl get endpointslices -l kubernetes.io/service-name=flask-app
kubectl port-forward service/flask-app 8080:80
```

With port-forward running, use a **second terminal**:

```bash
curl --fail http://127.0.0.1:8080/healthz
```

Expected: `{"status":"alive"}`. The Service selector must match the Deployment Pod label `app.kubernetes.io/name: flask-app`, and EndpointSlices must show eligible Pod backends.

**Controlled failure:** Copy the Service manifest, change its selector to an absent label, apply your copy and inspect EndpointSlices. Restore the original file:

```bash
kubectl apply -f manifests/chapter-04/flask-service.yaml
kubectl get endpointslices -l kubernetes.io/service-name=flask-app
```

Stop port-forward with Ctrl+C. **Keep** the Service and Deployment for the next chapter. If requests fail, investigate the request path—Service selector, ready Pod endpoints, target port, and application response.
