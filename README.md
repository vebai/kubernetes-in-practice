# Kubernetes in Practice

**Companion repository for *Kubernetes in Practice: Deploy, Secure, Scale, and Troubleshoot Applications with Minikube, Helm, and Amazon EKS* by Victor Ebai.**

## What you will gain from the book

A working container is only the beginning. When customers depend on an application, engineering teams must keep it available, release changes reliably, control resources and security, and find the cause when something fails. *Kubernetes in Practice* teaches those operational skills through one continuous, hands-on application journey—from a local Docker image to a production-style workload on Amazon EKS.

You will learn to:

- **Deploy and update applications confidently** using Pods, Deployments, Services, labels and selectors.
- **Keep services available** through health and readiness probes, scaling, controlled rollouts and recovery.
- **Configure and secure workloads** with ConfigMaps, Secrets, ServiceAccounts, RBAC, restricted Pod security and NetworkPolicy.
- **Diagnose failures using evidence** from Kubernetes status, events, logs, DNS, EndpointSlices and the request path.
- **Package repeatable releases** with Helm, then operate the application on Amazon EKS.

The book is designed to build engineering judgement, not simply familiarity with `kubectl`. Its practical method is **Build → Observe → Break → Diagnose → Fix → Verify**.

## How this repository helps

The book is **fully self-contained**: it teaches the concepts, decisions and complete exercises. This public companion gives you ready-to-use application source, Kubernetes YAML, a Helm chart and short lab guides, so you can spend more time building and validating rather than retyping configuration.

The example is a small Python Flask service with three endpoints: `/`, `/healthz` and `/readyz`. You will build it as an image, run it on Minikube, make it reliable and secure, package it with Helm and deploy it to EKS when you are ready.

**Want the complete learning path?** Read *Kubernetes in Practice* by Victor Ebai for the problem-first explanations, mental models, operational decisions and guided investigations that connect these exercises. The files here support the book; they are not a replacement for its teaching.

## Before you begin

Start with the [setup guide](docs/SETUP.md). You need Docker, `curl`, Git, a terminal, and later Minikube, `kubectl` and Helm. AWS CLI and `eksctl` are required only for the EKS part.

```bash
docker version
docker run --rm hello-world
kubectl version --client
```

You do **not** need an AWS account for the local chapters. EKS exercises create chargeable AWS resources; read [EKS safety and costs](docs/EKS-SAFETY.md) before proceeding.

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

## Quick start — local application

From your own terminal:

```bash
git clone https://github.com/vebai/kubernetes-in-practice.git
cd kubernetes-in-practice/flask-app
docker build -t flask-app:v1.0.0 .
docker run --rm -d --name flask-app -p 127.0.0.1:5050:5000 flask-app:v1.0.0
curl --fail http://127.0.0.1:5050/healthz
docker rm -f flask-app
```

Expected response: `{"status":"alive"}`. Then follow [Chapter 2](chapters/chapter-02-local-cluster/README.md) to create the local cluster and load the same image.

## Verification, troubleshooting and cleanup

The optional [chapter validation suite](validation/README.md) and [staged AWS live-validation suite](validation/aws-live/README.md) have separate execution boundaries. Read [what was actually tested](docs/VALIDATION-EVIDENCE.md) and the [book-to-repo path map](docs/REPO-BOOK-PATHS.md). A locally rendered EKS chart does not prove a live EKS cluster. EKS creation, deliberate faults and deletion each require explicit approval.


Run the **offline file checks** without deploying anything:

```bash
bash tests/validate-files.sh
```

They check Python syntax, static YAML structure, relative README links and repository hygiene. If Helm is installed, they also lint and render the chart. They do not prove a live Kubernetes or EKS deployment.

When something fails, read [Troubleshooting](docs/TROUBLESHOOTING.md) and first verify the active context, resource status, events and logs. For resource removal, follow [Safe cleanup](docs/CLEANUP.md); deleting the Helm release does **not** delete the EKS cluster or AWS load balancer automatically in every failure state.

This repository contains no live credentials or production secrets. The EKS exercises are optional and may incur AWS costs.
