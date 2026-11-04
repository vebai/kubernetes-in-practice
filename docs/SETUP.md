# Prepare your Kubernetes learning environment

Run these commands from your **own computer's terminal** (macOS, Linux or WSL 2). Commands without `$` are intended to be copied as written. Follow the matching chapter's README for the exact starting directory.

## 1. Docker and curl

Install and start Docker Desktop on macOS or Windows (enable Docker Desktop's WSL 2 integration for Linux commands on Windows), or Docker Engine on Linux. Ubuntu/Debian package option:

```bash
sudo apt update
sudo apt install -y docker.io curl
sudo systemctl enable --now docker
```

Fedora distribution package option:

```bash
sudo dnf install -y moby-engine curl
sudo systemctl enable --now docker
```

macOS with Homebrew:

```bash
brew install --cask docker-desktop
```

Start Docker Desktop manually. Check that the engine is accessible:

```bash
docker version
docker run --rm hello-world
curl --version
```

On Linux you may need an authorised `sudo docker` setup. Adding someone to the Docker group grants root-equivalent host privileges; do not do so casually. Use the official vendor installation guides when distribution packages differ.

## 2. Install and verify Minikube, kubectl and Helm

Follow the supported platform instructions for [Minikube](https://minikube.sigs.k8s.io/docs/start/), [kubectl](https://kubernetes.io/docs/tasks/tools/) and [Helm](https://helm.sh/docs/intro/install/). For macOS with Homebrew:

```bash
brew install minikube kubectl helm
```

Verify the installed tools:

```bash
minikube version
kubectl version --client
helm version
```

Chapters use the Kubernetes version documented in the book; verify the version is supported by your Minikube release. On a MacBook, Docker Desktop must be running before starting Minikube with the Docker driver. For the NetworkPolicy exercise, use a supported CNI with enforcement (the security lab uses Calico).

## 3. Start the local cluster (when you reach Chapter 2)

```bash
minikube start --driver=docker
kubectl config current-context
kubectl get nodes
```

Expected current context: `minikube`; the node eventually reports `Ready`. If you have other Kubernetes contexts, explicitly switch to `minikube` before applying resources.

## 4. Optional AWS EKS tools (Chapters 10–12 only)

Install [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [`eksctl`](https://eksctl.io/installation/) from their official sources. Configure a non-production AWS identity with appropriate permissions; prefer temporary, federated credentials over static access keys. Verify:

```bash
aws --version
eksctl version
aws sts get-caller-identity
```

Choose `eu-west-2` (London) for the documented EKS example, or adjust every EKS-related file consistently. Check the available EKS Kubernetes versions before creating a cluster. Read [AWS costs and safety](EKS-SAFETY.md) first.

## General rules

- Work from the repository root unless the chapter guide says otherwise.
- Never put credentials, access keys, real secrets or personal kubeconfig files into Git.
- A failed command is a reason to inspect the error, version, context, prerequisites and permissions—not to delete resources indiscriminately.
