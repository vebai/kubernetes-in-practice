# Chapter 1 — Prepare an application for Kubernetes

**Goal:** Build the Flask image once, prove its endpoints respond, verify that the application runs without root privileges, and diagnose a deliberately incorrect port mapping.

**Starting state:** Docker Engine/Desktop and `curl` are working. Follow the [setup guide](../../docs/SETUP.md) if needed. Run commands from your **local terminal**, from the repository root unless `cd` is shown.

## Build and observe

```bash
cd flask-app
docker build -t flask-app:v1.0.0 .
HOST_PORT=5050
docker run -d --name flask-app -p "127.0.0.1:${HOST_PORT}:5000" \
  -e APP_VERSION=v1.0.0 flask-app:v1.0.0
docker ps --filter name=flask-app
docker inspect --format '{{.Config.User}}' flask-app
curl --fail http://127.0.0.1:5050/
curl --fail http://127.0.0.1:5050/healthz
curl --fail http://127.0.0.1:5050/readyz
```

Expected: the container is `Up`, its configured user is `1001:1001`, `/healthz` returns `{"status":"alive"}`, and `/readyz` returns `{"status":"ready"}`.

## Break, diagnose, repair

Remove the lab container, then deliberately use an incorrect **container port** (`5001` rather than `5000`):

```bash
docker rm -f flask-app
docker run -d --name flask-app -p 127.0.0.1:5050:5001 flask-app:v1.0.0
curl --fail http://127.0.0.1:5050/healthz   # expected to fail
docker ps --filter name=flask-app
docker port flask-app
docker logs flask-app
```

The app still listens on port 5000. Repair **only** the mapping:

```bash
docker rm -f flask-app
docker run -d --name flask-app -p 127.0.0.1:5050:5000 flask-app:v1.0.0
curl --fail http://127.0.0.1:5050/healthz
docker rm -f flask-app
```

**Keep** the `flask-app:v1.0.0` image for Chapter 2. A port in use or Docker permissions error should be diagnosed before retrying.
