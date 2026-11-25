# Chapter 4 — Services, DNS and the request path

**Goal:** Give the Chapter 3 Deployment a stable ClusterIP Service, verify backends through EndpointSlices and isolate a selector mismatch.

Run from the **repository root** using the same local context as Chapter 3 (`minikube` or the separate profile you started in Chapter 2). Confirm it before applying the Service:

```bash
kubectl config current-context
kubectl get deployment flask-app
kubectl apply -f manifests/chapter-04/flask-service.yaml
kubectl get service flask-app
kubectl get endpointslices -l kubernetes.io/service-name=flask-app
kubectl port-forward --address 127.0.0.1 service/flask-app 18080:80
```

Wait for `Forwarding from 127.0.0.1:18080 -> 5000`. Leave that terminal open and use a **second terminal**:

```bash
curl --fail http://127.0.0.1:18080/healthz
```

Expected: `{"status":"alive"}`. The Service selector must match the Deployment Pod label `app.kubernetes.io/name: flask-app`, and EndpointSlices must show eligible Pod backends.

> [!WARNING]
> If the port is already in use, pick another local port and use it in both commands. If an earlier port-forward prints only `Forwarding from [::1]:8080` and an IPv4 request to `127.0.0.1:8080` returns HTTP 403, another local service may be answering that request. Stop the old port-forward with Ctrl+C and use the explicit IPv4 command above.

**Controlled failure:** Copy the Service manifest, change its selector to an absent label, apply your copy and inspect EndpointSlices. Restore the original file:

```bash
kubectl apply -f manifests/chapter-04/flask-service.yaml
kubectl get endpointslices -l kubernetes.io/service-name=flask-app
```

Stop port-forward with Ctrl+C. **Keep** the Service and Deployment for the next chapter. If requests fail, investigate the request path—Service selector, ready Pod endpoints, target port, and application response.
