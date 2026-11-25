# Kubernetes in Practice

This is the companion repository for the book *Kubernetes in Practice: Build, Operate, Troubleshoot, and Secure Kubernetes Applications with Confidence* by **Victor Ebai**. It provides the sample Flask application, Kubernetes manifests, Helm chart, EKS configurations, and chapter-by-chapter lab guides.

## Get the paperback

**[Amazon UK — Paperback](https://www.amazon.co.uk/dp/B0HPGS53FY)** · [Amazon US — Paperback](https://www.amazon.com/dp/B0HPGS53FY) · [Amazon India — Find paperback by ISBN](https://www.amazon.in/s?k=9798165672880&i=stripbooks)

**Quick navigation:** [Getting started](#getting-started) · [Chapter index](#choose-your-chapter) · [Lab structure](#how-the-exercises-fit-together) · [Validation](#validate-the-files) · [Cleanup](docs/CLEANUP.md)

## From Docker image to Kubernetes and Amazon EKS

Follow a small, non-root Python Flask service from a local container image through Pods, Deployments, Services, probes, configuration, security, scaling, and Helm. Use Minikube for the local labs, with an optional path to managed Kubernetes on Amazon EKS.

![Kubernetes in Practice learning overview: application code becomes a Docker image, is packaged with a Helm chart, and runs as a Kubernetes workload with Deployments, Services, Ingress, configuration, scaling, security, and monitoring; Minikube is the local environment and Amazon EKS is the optional AWS environment.](docs/images/kubernetes-overview.png)

*One application, progressively operated through Docker, Kubernetes and Helm. Minikube supports local learning; Amazon EKS is optional and creates chargeable cloud resources.*

**The book is fully self-contained.** You do not need this repository to understand or complete its learning path. The repository provides convenient, testable copies of the application, configurations, and lab instructions.

Build a container image, deploy and expose a Kubernetes application, **verify readiness and recovery**, add security and scaling controls, release through Helm, and optionally practise operations on Amazon EKS.

The practical workflow is **Build → Deploy → Observe → Break → Diagnose → Recover → Verify**. Use the book for the explanations and engineering judgement; use this repository for runnable examples, guided checks, and safe cleanup.

## What you will build and practise

By working through the exercises, you will learn to:

- **Package and verify a non-root Flask container** with `/`, `/healthz`, and `/readyz` endpoints.
- **Deploy and update workloads** using Pods, Deployments, Services, and Kubernetes networking.
- **Manage application configuration** using ConfigMaps, Secrets, health probes, and resource limits.
- **Inspect scaling, security, and failures** using HPA, RBAC, NetworkPolicy, logs, and events.
- **Package and release with Helm**, then optionally build an ECR/EKS deployment and verify recovery.

The same Flask service develops through the chapters so you can recognise how each additional control changes its behaviour.

## Before you begin

**First-time setup:** [Prepare Docker, Minikube, kubectl, Helm, and your terminal](docs/SETUP.md).

You need:

- **Docker Desktop** (macOS/Windows) or **Docker Engine** (Linux), plus **Git** and **`curl`** for the first chapter.
- **Minikube** and **`kubectl`** when you start the local Kubernetes exercises (Chapter 2).
- **Helm** for the packaging and release chapters (from Chapter 9).
- A macOS or Linux terminal, or a Bash-compatible WSL 2 environment on Windows.
- **Optional AWS CLI v2, `eksctl`, and an authorised AWS account** only for the EKS exercises (Chapters 10–12).

The AWS examples target **London (`eu-west-2`)**. Check supported EKS versions and current AWS permissions before creating a cluster. A local Kubernetes cluster does not require an AWS account.

**Cost and security:** Local exercises may consume CPU and memory. EKS, ECR, load balancers, and related resources can incur charges. Review [EKS safety and costs](docs/EKS-SAFETY.md), check your exact Kubernetes context, keep credentials out of Git, and follow [safe cleanup](docs/CLEANUP.md). NetworkPolicy enforcement requires a compatible CNI.

## Getting started

**1. Clone the repository** in your terminal:

```bash
git clone https://github.com/vebai/kubernetes-in-practice.git
cd kubernetes-in-practice
```

**2. Verify the Chapter 1 container** on your own computer, with Docker running:

```bash
cd flask-app
docker build -t flask-app:v1.0.0 .
docker run --rm -d --name flask-app -p 127.0.0.1:5050:5000 flask-app:v1.0.0
curl --fail http://127.0.0.1:5050/healthz
docker stop flask-app
cd ..
```

The expected health response is `{"status":"alive"}`. If the initial request arrives before Flask is ready, retry it before stopping the container.

**3. Continue to Kubernetes** using the [Chapter 2 local cluster guide](chapters/chapter-02-local-cluster/README.md). Check `kubectl config current-context` before applying any manifest.

**4. Validate files without creating a cluster** using the offline checker:

```bash
bash tests/validate-files.sh
```

See [validation](validation/README.md) for optional local runtime tests and the separate [AWS live-validation guide](validation/aws-live/README.md) before attempting EKS deployments.

**New to Docker?** [*Docker in Practice* (UK paperback)](https://www.amazon.co.uk/dp/B0HPGQQ86V) covers images, Dockerfiles, Compose, and container debugging; its [companion examples](https://github.com/vebai/docker-in-practice) are freely available.

## Choose your chapter

| Chapter | What you will practise | Files / guide |
|---|---|---|
| 1 | Build and verify the versioned, non-root Flask container | [Prepare the application](chapters/chapter-01-prepare-application/README.md) |
| 2 | Start Minikube, inspect context and run the first Pod | [Local cluster](chapters/chapter-02-local-cluster/README.md) |
| 3 | Deploy, scale, update and recover a workload | [Deployments](chapters/chapter-03-deployments/README.md) |
| 4 | Create a Service and trace the request path | [Services and DNS](chapters/chapter-04-services-dns/README.md) |
| 5 | Inject application configuration and handle lab secrets | [Configuration](chapters/chapter-05-configuration/README.md) |
| 6 | Add probes, resource controls and a CPU-based HPA | [Health and scaling](chapters/chapter-06-health-scaling/README.md) |
| 7 | Apply restricted workload security, RBAC and NetworkPolicy | [Security](chapters/chapter-07-security/README.md) |
| 8 | Diagnose common failures without guessing | [Troubleshooting](chapters/chapter-08-troubleshooting/README.md) |
| 9 | Build, lint and release the application through Helm | [Helm](chapters/chapter-09-helm/README.md) |
| 10 | Push an image to ECR and optionally deploy to Amazon EKS | [EKS deployment](chapters/chapter-10-eks/README.md) |
| 11 | Observe, secure and operate an EKS workload | [EKS operations](chapters/chapter-11-eks-operations/README.md) |
| 12 | Validate a production-style release and exercise recovery | [Final project](chapters/chapter-12-final-project/README.md) |

## How the exercises fit together

**Local foundation (Chapters 1–6).** Build the initial app in [`flask-app/`](flask-app/), then run local Kubernetes examples under [`manifests/`](manifests/). Each guide says which files to use. The later application variants are under [`flask-app/versions/`](flask-app/versions/) because the book adds readiness and CPU-work behaviour progressively.

**Separate security lab (Chapter 7).** The manual book lab uses `security-lab`; the automated validation uses a distinct `book-k8s-security` Minikube profile and the `shop` namespace, with Calico enforcement. Do not mix the two contexts. The CNI must support NetworkPolicy enforcement.

**Helm and AWS (Chapters 9–12).** The chart lives in [`helm/flask-app/`](helm/flask-app/) with development and EKS values. You can lint and render a chart locally before installing it. The EKS templates are under [`eks/`](eks/) and are **never applied automatically**.

Verify your target first:

```bash
kubectl config current-context
kubectl get nodes
```

**A valid YAML file is not permission to apply it.** Always check namespace, cluster context, image name, required tools, and any secrets before making changes.

The optional EKS labs require AWS CLI v2, `eksctl` and an appropriately authorised AWS identity. Read [EKS safety and costs](docs/EKS-SAFETY.md) and [safe cleanup](docs/CLEANUP.md) before creating chargeable resources.

## Validate the files

From the repository root, run the offline checks with Python 3 installed. Install PyYAML for YAML checks and Helm for chart checks.

```bash
bash tests/validate-files.sh
```

The script checks Python syntax, relative Markdown links and repository hygiene. With PyYAML installed, it also checks static YAML structure. With Helm installed, it also lints and renders the chart using the development values. These checks run without a cluster.

For runtime checks, use the separate [local chapter validation suite](validation/README.md) or the [staged AWS live-validation guide](validation/aws-live/README.md). See the [chapter file map](docs/REPO-BOOK-PATHS.md) to locate the supplied files. The validation suite documents what each automated check covers. If a lab fails, start with the [troubleshooting guide](docs/TROUBLESHOOTING.md).

## Continue with the book

**[Amazon UK paperback](https://www.amazon.co.uk/dp/B0HPGS53FY)** for the complete exercises, architecture explanations and guided troubleshooting investigations.

## Licence

The runnable code and Kubernetes configurations are available under the [MIT License](LICENSE). Book text and illustrations remain © 2026 Victor Ebai.
