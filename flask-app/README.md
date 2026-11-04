# Flask test application

The application deliberately stays small so you can practise Kubernetes operations rather than application development. It exposes `/`, `/healthz` and `/readyz` on port 5000 and accepts `APP_NAME`, `APP_VERSION` and `APP_MESSAGE` as environment variables.

- This directory is the **Chapter 1 `v1.0.0` baseline**.
- [`versions/v2.1.0/`](versions/v2.1.0/) adds a visible readiness delay (Chapter 6).
- [`versions/v2.2.0/`](versions/v2.2.0/) adds synthetic CPU work and threaded Gunicorn (Chapter 6).
- [`versions/v2.3.0/`](versions/v2.3.0/) is the hardened application-image baseline used with Chapter 7, Helm and EKS.

From `flask-app/`:

```bash
docker build -t flask-app:v1.0.0 .
docker run --rm -d --name flask-app -p 127.0.0.1:5050:5000 flask-app:v1.0.0
curl --fail http://127.0.0.1:5050/healthz
docker rm -f flask-app
```

To build the later version, for example:

```bash
docker build -t flask-app:v2.3.0 ./versions/v2.3.0
```

These images are **local** until deliberately published to a registry. For local Minikube, load them into the correct Minikube profile before deploying with `imagePullPolicy: Never`.
