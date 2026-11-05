# Book ↔ companion repository path reconciliation

The paperback teaches readers to **create the files themselves** in working directories such as `chapter-09/` and `chapter-10/`. The ready-to-run GitHub companion is organised differently for reuse. These are two **alternative workflows**, not two directories that must both exist.

| Reader-built path in the book | Companion path from repository root |
|---|---|
| `flask-app/` (Chapter 1 source) | `flask-app/` |
| Chapter 6 app variant | `flask-app/versions/v2.2.0/` |
| Hardened Chapter 7/10 variant | `flask-app/versions/v2.3.0/` |
| `chapter-09/flask-app/` Helm chart | `helm/flask-app/` |
| `chapter-09/values-development.yaml` | `helm/values-development.yaml` |
| `chapter-09/values-production.yaml` | `helm/values-production.yaml` |
| `chapter-10/values-eks.yaml` | `eks/values-eks.yaml` |
| Chapter 12 capstone overrides | `eks/values-capstone.yaml` |
| EKS cluster, IngressClass files | `eks/cluster.yaml`, `eks/alb-ingress-class*.yaml` |
| Chapter-specific Kubernetes YAML | `manifests/chapter-XX/` |

Run these **from the repository root** when using the companion files:

```bash
bash tests/validate-files.sh
bash validation/preflight.sh
helm lint helm/flask-app -f helm/values-development.yaml
helm template flask-app helm/flask-app -n flask -f eks/values-capstone.yaml \
  --set-string image.repository=EXAMPLE_ECR_REGISTRY/flask-app
```

The final `helm template` is a **render-only** example: replace its placeholder with the actual registry only when you own the relevant AWS account. Do not use this example as permission to deploy or create an EKS cluster. For cost-controlled AWS lab validation, use `validation/aws-live/README.md`.

Chapter 7's **manual manuscript lab** names the isolated Minikube profile `security-lab`. The **automated test harness** deliberately names its dedicated profile `book-k8s-security` to distinguish tests from hand-built exercises. Keep the paths and contexts consistent within the workflow you choose. Never assume a local context is an EKS context.
