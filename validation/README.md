# Kubernetes in Practice — chapter validation pack

This drop-in pack is for the existing repository at <https://github.com/vebai/kubernetes-in-practice>. It does not overwrite the manuscript, application, manifests, chart or repository root README. Install the **entire `validation/` directory at the repository root**.

## Requirements

Mac/Linux terminal with `bash`, `python3`, Docker Engine/Desktop running, `curl`, `kubectl`, `minikube` and `helm`. Chapters 10–12 additionally support read-only `aws` CLI checks, but the local suite requires no AWS identity. Static checks require PyYAML. No root privileges are requested by these scripts.

For macOS with Homebrew, install missing CLI tools using official installation guidance; Docker Desktop must also be running. If PyYAML is missing:

```bash
python3 -m venv .validation-venv
.validation-venv/bin/pip install PyYAML
PATH="$PWD/.validation-venv/bin:$PATH" bash validation/preflight.sh
```

The venv is optional when your current Python already has PyYAML installed. This pack does not download or install dependencies automatically.

## Start here

From the cloned **repository root**:

```bash
bash validation/preflight.sh
bash validation/run.sh 01
bash validation/run.sh 02 03 04 05 06
bash validation/run.sh 07
bash validation/run.sh 08 09
```

Alternatively, `bash validation/run.sh` runs Chapters 01–09 in order, stopping at the first failure. After fixing a failure, resume from that chapter; the tests have named steps and preserve failure-state resources for diagnosis. Logs and rendered Helm YAML are in `validation/.logs/` (git-ignored). Never commit those logs without reviewing their contents, especially after AWS inspection.

## Validation coverage

| Chapter | Main live outcome |
|---|---|
| 01 | Container builds, non-root UID, `/`, `/healthz`, `/readyz`, deliberate wrong port and repair |
| 02 | Pod starts in an isolated Minikube profile, correct image and UID, healthy HTTP |
| 03 | Three replicas, Pod replacement, broken image rollout, rollback and health |
| 04 | Service selector, ready EndpointSlices, in-cluster DNS, selector fault and recovery |
| 05 | ConfigMap-driven message, disposable Secret, missing-ConfigMap fault and repair |
| 06 | Startup/readiness/liveness, resource settings, Metrics Server, HPA metrics; optional CPU scale-out |
| 07 | Separate Calico profile, restricted workloads, named-ConfigMap RBAC yes/no, both-clients-before and allowed-vs-denied-after NetworkPolicy traffic |
| 08 | Five failures (image, ConfigMap, readiness, Service selector, crashing process) with recovery after each |
| 09 | Helm lint, rendering, live install/upgrade, workload and service response |
| 10 | EKS config and Helm render; optional **read-only** existing EKS/ECR checks |
| 11 | Optional **read-only** EKS operations inspection |
| 12 | Capstone chart controls; optional **read-only** EKS release inspection |

All Kubernetes calls specify an explicit context and namespace. Main local tests use `book-k8s-validation`. Chapter 7 uses a separate `book-k8s-security` profile with Calico, because NetworkPolicies are not reliably enforceable using a default Minikube CNI. Minikube profile creation is enabled only for those dedicated names and no cluster deletion is automated. You can override the profile names, but do so only if they are **disposable, isolated lab clusters**.

The suite annotates created lab resources with `book.validation/owner=kubernetes-in-practice`. It refuses to overwrite pre-existing objects of the same name that lack that annotation. The exception is Helm release ownership in its own suite-created namespace; examine the dedicated cluster if you have reused it for unrelated work. Do not point this validation harness at production.

## Behaviour switches

| Variable | Default | Function |
|---|---|---|
| `K8S_FAULTS` | `1` | Enable destructive-but-contained local fault injection |
| `K8S_CREATE_LOCAL_PROFILE` | `1` | Allow creating the named local Minikube profile |
| `K8S_CREATE_SECURITY_PROFILE` | `1` | Allow creating named Calico profile |
| `K8S_HPA_LOAD` | `0` | Run optional bounded local CPU load and require HPA scale-out |
| `K8S_STOP_OTHER_PROFILE` | `1` | Stop (never delete) the other suite-owned Minikube profile to conserve RAM during Chapter 7 |
| `K8S_HELM_CLEANUP` | `0` | Uninstall the local `flask-app` Helm release after Chapter 9 success |
| `K8S_VALIDATION_PROFILE` | `book-k8s-validation` | Main local profile |
| `K8S_SECURITY_PROFILE` | `book-k8s-security` | Security profile |
| `K8S_AWS_READONLY` | `0` | Check real EKS and AWS resources (never create, update or delete) |
| `K8S_VALIDATION_LOG_DIR` | `validation/.logs` | Evidence output directory |

For the *full* HPA scale-out experiment, after Chapter 06 succeeds, run:

```bash
K8S_HPA_LOAD=1 bash validation/run.sh 06
```

The one-Pod CPU load is deliberately bounded. If the node is under-resourced or Metrics Server is delayed, this stage may require diagnosis rather than changing the workload blindly.

## AWS EKS: separate read-only phase

The EKS YAML references `flask-eks` in `eu-west-2` on Kubernetes `1.36`; always check that this version and cluster type are supported before a paid deployment. A synthetic registry is used for the local Helm render. It is **never pushed**.

Safe offline commands:

```bash
bash validation/run.sh 10 11 12
```

That proves only file/chart checks. Live checks require an already-created EKS cluster and a configured kubeconfig context **and will not create one**. First verify the exact AWS account and context yourself, then in your local terminal set:

```bash
export K8S_AWS_READONLY=1
export K8S_EXPECTED_AWS_ACCOUNT=YOUR_12_DIGIT_AWS_ACCOUNT_ID
export K8S_EKS_CONTEXT=YOUR_EXACT_EKS_CONTEXT
export AWS_REGION=eu-west-2
bash validation/run.sh 10 11 12
```

The script checks the AWS account ID and compares the configured kubeconfig API server to the actual EKS cluster endpoint before doing read-only Kubernetes requests. Add `K8S_EKS_TEST_URL` only after verifying your own ALB URL and intending to test it.

A real Chapter 10–12 implementation test still requires deliberate ECR publishing, cost-approved EKS deployment, Helm installation, ALB health tests, rollback exercises and verified cloud cleanup. These are **not** automated or claimed passed in this pack.

## Safety and expected cleanup

- `01` removes only a container that carries its own validation label; it retains images.
- `02` removes the standalone validation Pod; `03` and `04` leave Deployment/Service for subsequent chapters.
- `05` removes only its disposable Secret; `06` removes only its HPA.
- `07` retains the security cluster and stops it on success to conserve memory (restart using `minikube start -p book-k8s-security` to inspect). If you own it and no other workloads use it, you may explicitly run `minikube delete -p book-k8s-security` later.
- `09` retains the Helm release by default. Optional `K8S_HELM_CLEANUP=1` removes the release, not the namespace or cluster.
- `10`–`12` run no AWS mutation commands. AWS charges, if any, are from your pre-existing cloud resources and are **not stopped** by these scripts.

Do not run broad `kubectl delete --all`, `minikube delete` or `docker system prune` as part of fault diagnosis. Preserve the log and resource state after an unexpected failure. The scripts print the failing checkpoint and collect Pods, events, logs and Deployment state.

## Send evidence for correction

After any failure, send the `CHAPTER`, `checkpoint`, and relevant content from `validation/.logs/chapter-XX-*.log`. Before sharing, redact AWS account IDs, cluster endpoint details, environment-specific configuration and any sensitive service output. Re-run the same chapter after applying one justified correction.

## What has actually been checked in the creation environment

The scripts were authored against repository source retrieved from GitHub and the supplied paperback manuscript. Original local Chapters 1–9 were live-tested on 5 November 2026; v1.9 ownership-recovery guard is fixture-tested, while optional load-driven HPA scale-out is unproved. Shell syntax (`bash -n`) and Python syntax were checked. This generation environment has **no Docker, kubectl, Minikube, Helm, AWS CLI or live cluster**, so its creator **cannot report runtime test passes**. The final overlay does not repeat those earlier successful live runs automatically. See ../docs/VALIDATION-EVIDENCE.md for the exact coverage and remaining limitations.

## Troubleshooting Docker Desktop resource allocation (v1.1)

The Minikube Docker driver uses memory and CPUs **allocated to Docker Desktop**, not the total installed Mac memory. The default main profile requests 6144 MiB and 3 CPUs. The separate security profile requests 4096 MiB and 2 CPUs. This pack requires an extra 256 MiB of Docker VM headroom and checks the allocations during preflight and before creating either profile.

To confirm the Docker allocation from the repository root:

```bash
docker info --format '{{.MemTotal}}' | awk '{printf "Docker RAM: %.2f GiB\n", $1/1024/1024/1024}'
docker info --format '{{.NCPU}} CPUs'
minikube version
```

If Docker reports around 1985 MiB, open **Docker Desktop → Settings → Resources → Advanced**, increase the RAM allocation if your host can support it, and restart Docker Desktop. For the default 6-GiB main profile, 8 GiB Docker memory and at least 3 CPUs is a suitable choice on a machine with ample physical memory.

On a smaller Mac, **do not** set Docker Desktop to 8 GiB if that would starve the operating system. You can choose a smaller, explicit cluster when the Docker VM has enough headroom (labs may then run less reliably):

```bash
export K8S_LOCAL_MEMORY=4096
export K8S_LOCAL_CPUS=2
export K8S_SECURITY_MEMORY=3072
export K8S_SECURITY_CPUS=2
bash validation/preflight.sh
bash validation/run.sh 02 03 04 05 06
```

Use the reduced configuration only if Docker has at least 4352 MiB allocated for the main profile and at least 3328 MiB for the security profile. Chapter 6 Metrics Server and Chapter 7 Calico can still need more RAM. Profiles already created with a different size may require `minikube -p book-k8s-validation stop` followed by a deliberate `minikube -p book-k8s-validation start --memory=4096 --cpus=2` rather than an implicit resize. Do not delete profiles just to retry.

The validation runner now produces a **capacity blocker before profile creation**, avoids noisy diagnostics for a missing cluster context, and prints the attempt on which each Chapter 1 HTTP retry succeeds. A transient curl error is not a pass by itself: subsequent successful HTTP and JSON assertions are required.

If the Chapter 1 Gunicorn output reports `Control server error: Permission denied '/home/appuser'`, the Flask endpoints can still work; consider adding `--no-control-socket` to the Gunicorn `CMD` in each of the book's four Dockerfiles (`flask-app/Dockerfile` and `flask-app/versions/v2.1.0`, `v2.2.0`, `v2.3.0`). This source-file improvement is **not** silently applied by this validation overlay.


## v1.2 compatibility and image recovery

Chapter 2 rebuilds `flask-app:v1.0.0` from the repository when an upgrade or Docker context change removes the local image. It does not repeat Chapter 1's fault simulation.

Preflight rejects old Minikube releases. Live local validation also verifies that the Kubernetes API server version is supported by the `kubectl` client (within one minor version) and is within the test baseline (Kubernetes 1.35 or newer). These checks prevent apparent success on an obsolete cluster.

If a previous run created the *dedicated* `book-k8s-validation` profile with Kubernetes 1.20, inspect `minikube profile list` and then, once confirmed, run `minikube delete -p book-k8s-validation` after upgrading Minikube. Do not delete other profiles.

## Validation v1.3 — Chapter 3 self-healing wait correction

Chapter 3 now polls the **current** Pod list after deleting one Deployment-owned
Pod. It requires the deleted Pod to disappear and exactly three non-terminating,
Running, Ready Pods to exist, followed by three available Deployment replicas.
This corrects a false timeout in v1.2 caused by `kubectl wait` tracking the
original, deleted Pod. v1.3 also explicitly restores the Service selector after
Chapter 4's controlled fault and resets image, readiness-probe and command
fields after Chapter 8's controlled faults, rather than assuming `kubectl apply`
undoes changes made outside its last-applied configuration. The new Chapter 3
script can also rebuild a missing v1.0.0 image. It does **not** modify any book manifests.

To resume an already-running Chapter 3 cluster:

```bash
bash validation/run.sh 03
```

Chapter 3 may safely reapply its owned Deployment and repeat the one-Pod
reconciliation exercise. Only proceed to Chapters 4–6 after Chapter 3 prints
`[PASS]`.

### Chapter 4 Service propagation

A ready EndpointSlice does not guarantee the node has finished programming Service
forwarding. Chapter 4 separately checks Pod loopback HTTP, DNS resolution against
the actual ClusterIP, and Service HTTP (up to 45 attempts, 2 seconds apart).
Persistent failures remain failures and print targeted Service/EndpointSlice/kube-proxy evidence.
Use `bash validation/run.sh 04 05 06` to resume without rerunning Chapter 3.

## Chapter 4: selector recovery and asynchronous EndpointSlices

Chapter 4 now polls for up to 120 seconds (`K8S_ENDPOINT_DRAIN_TIMEOUT=120`, override as needed) after deliberately changing the Service selector. It verifies the Service fails through HTTP and restores the canonical selector. On an interrupted fault exercise it attempts to restore the selector automatically. Only the `book.validation/owner=kubernetes-in-practice`-annotated Service in the dedicated validation context is modified.

If a previous run left the Service selector altered, rerunning `bash validation/run.sh 04` first restores that selector. To inspect it without changing anything:

```bash
kubectl --context=book-k8s-validation -n default get svc flask-app -o yaml
```

If automatic recovery fails, and **only after** confirming that this is the lab-owned Service in the `book-k8s-validation` context, restore it manually:

```bash
kubectl --context=book-k8s-validation -n default patch svc/flask-app \
  --type=json -p '[{"op":"replace","path":"/spec/selector","value":{"app.kubernetes.io/name":"flask-app"}}]'
```

Never apply this command to a shared or EKS cluster.

### EndpointSlice parsing regression (v1.6)

`validation/endpoint-count.py` counts ready, addressed EndpointSlice backends from
`kubectl ... -o json`. It correctly treats `"endpoints": null`, missing endpoints,
and empty arrays as **zero**. Invalid JSON or an API error is reported rather than
mistaken for zero. `validation/preflight.sh` runs 11 offline regression cases.

The Chapter 4 fault test deliberately changes the selector **only on the
validation-owned Service**. Its exit trap restores the selector on errors; it
does not mutate other Services or clusters. Use `bash validation/run.sh 04` after
installing a newer overlay; then continue with `05 06` if it passes.

## v1.8 — Chapter 7 RBAC denial handling

`kubectl auth can-i` prints `yes` with exit 0 when permission is granted, and
prints `no` with exit 1 when permission is denied. Chapter 7 now captures
both response and exit code without triggering `set -e`. It confirms the
`config-reader` ServiceAccount can get `flask-config` and is denied an
unrelated ConfigMap, ConfigMap listing and Secrets. API errors and unexpected
permissions still cause a failure. `validation/test-rbac-check.sh` runs eight
offline regression cases during preflight. The Calico security profile and
existing hardened Deployment are retained across validation failures.

Resume at `bash validation/run.sh 07`; the script reuses the security profile.

## Final v1.9 ownership recovery

An older Chapter 8 restore path used plain `kubectl apply` and could leave the Chapter 6 ConfigMap without the lab ownership marker. Chapter 6 now recovers **only that precise historical case**: the ConfigMap must exactly match canonical Chapter 6 data, context must be `book-k8s-validation`, and the Deployment and Service must already carry the correct marker. Otherwise the script stops rather than overwriting an unknown object. Later `restore_six` operations consistently reapply the marker. Run `python3 validation/test-configmap-owner.py` for eleven regression cases. Optional HPA scale-out remains outstanding.
