# Validation evidence and limits — 5 November 2026

This companion repository supports *Kubernetes in Practice* by Victor Ebai. This record separates **live observation** from rendering checks and intentionally untested resilience claims.

## Live local verification — Chapters 1–9

The author's dedicated Intel macOS test machine ran Docker Desktop, Minikube v1.39.0, Kubernetes v1.37.0 (local), kubectl v1.36.5 and Helm v4.3.0. The main local profile was `book-k8s-validation`; the Calico isolation profile was `book-k8s-security`.

- 01–03: image, Pod and Deployment creation; three replicas, error injection and recovery.
- 04: real Service DNS and HTTP; selector mismatch produced zero EndpointSlice backends and blocked HTTP, then recovered.
- 05: ConfigMap/Secret lifecycle; missing ConfigMap caused a real container error, then recovered.
- 06: probes, Metrics Server and HPA `ScalingActive`; **CPU-driven HPA scale-out not proved**. One optional retest stopped at a legacy ConfigMap ownership-marker check. The final script has a narrowly scoped fix and offline tests, but has not been rerun against the live local cluster.
- 07: least-privilege RBAC decisions, actual Calico NetworkPolicy allowed/denied requests, baseline connectivity before policy, and recovery. Three hardened replicas Ready.
- 08: five intentionally broken paths and working service after repair.
- 09: Helm lint, templating, live install and in-cluster HTTP; `v2.3.0` response verified.

The archived chapter logs remain on the author's machine under `validation/.logs/`, never in the public repository.

## AWS live verification — Chapters 10–12

On 5 November 2026, the author's separate AWS lab in **eu-west-2** used EKS Auto Mode with Kubernetes **1.36**, the `flask-eks` cluster, Helm 4, an ECR `flask-app:v2.3.0` image and a restricted internet-facing ALB. Charges were explicitly approved.

- **10 — Deployment:** ECR image digest present; cluster `ACTIVE`; 2/2 Ready Flask Pods; Helm release; ALB DNS; external `/` and `/healthz` returned the expected responses. Metrics Server initially reported `DEGRADED` with `InsufficientNumberOfReplicas` because capacity was not yet schedulable, then recovered to `ACTIVE` after bounded polling. CPU metrics and HPA `ScalingActive` were confirmed.
- **11 — Operations:** two Ready EKS nodes existed in **eu-west-2b and eu-west-2c**; application Pods were both on **one node in eu-west-2c**. Both ALB targets reported healthy; live external HTTP worked. Resource metrics and Helm history were observed.
- **12 — Capstone:** 3/3 replicas; HPA range 3–6; PDB `minAvailable: 2`; real Pod deletion and replacement; external traffic after replacement; deliberate failed Helm image upgrade (revision 3); automatic rollback to known-good release (revision 4); restored `v2.3.0` and working external ALB HTTP. All three app Pods were still on **one node**, not spread across two AZs.
- **Cleanup:** `eksctl` reported cluster deletion complete. Subsequent read-only CLI checks returned **no EKS clusters, no ECR repositories, no ELBv2 load balancers and no CloudFormation stacks in CREATE_COMPLETE or DELETE_FAILED** within eu-west-2. This does not itself prove absence of NAT gateways, EIPs, ENIs, VPCs, EC2 instances or delayed charges; inspect those independently.

**Important evidence boundary:** the tested AWS scripts validate a narrower, explicit path than every manuscript exercise. The live AWS run **did not prove** load-driven HPA scale-out, PDB eviction enforcement, multi-node/multi-AZ application survival, EKS NetworkPolicy enforcement, all four Chapter 12 failure scenarios, database recovery, HTTPS, or complete cost elimination.

## Source and reproduction boundaries

The final local harness is under `validation/` and the separate chargeable AWS harness is under `validation/aws-live/`. The original live execution used local validation v1.8 and AWS validation v1.3, followed by the maintenance fixes supplied in this package (local v1.9, AWS v1.4). These fixes include strict ConfigMap ownership migration, Gunicorn control-socket disabling, a supported Helm 4 rollback flag, quiet replacement polling and initial Metrics Server recovery. **Do not claim these final edits were tested live in AWS after cleanup.**

Read `../validation/README.md` for local testing and `../validation/aws-live/README.md` for the guarded AWS process. AWS scripts demand exact account and separate approval tokens for creation, fault injection and destruction. Do not publish account IDs, kubeconfigs, AWS endpoints, tokens or raw logs.
