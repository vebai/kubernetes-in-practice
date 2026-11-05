# Manuscript reconciliation — manual edits only

**Source checked:** `Kubernetes in Practice v2 papperback(2).docx`, supplied 5 November 2026. No changes have been made to the Word file. Confirm location with Word Find because pagination may change. Preserve the book's chapter sequence and complete standalone code listings.

## 1. Introduction → Working with the Code

**Find** (exact): `You do not need a separate code repository to complete the labs.`

**After this sentence, add:**

> The optional companion repository at https://github.com/vebai/kubernetes-in-practice provides the same application, Kubernetes manifests, Helm chart and chapter guides as ready-to-use files. Clone it with `git clone https://github.com/vebai/kubernetes-in-practice.git` and run the repository commands from the cloned directory unless a chapter says otherwise. The book remains self-contained: the repository supports the exercises and does not replace their explanations or source listings. See `docs/REPO-BOOK-PATHS.md` in the repository for the path mapping and `docs/VALIDATION-EVIDENCE.md` for verified coverage.

## 2. Chapter 1 → Dockerfile Listing 1.3

**Find:** `CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "--error-logfile", "-", "app:app"]`

**Replace with:** `CMD ["gunicorn", "--no-control-socket", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "--error-logfile", "-", "app:app"]`

Gunicorn 26.2.0 attempts to create a control socket under the runtime user's home by default, producing a permission warning with this non-root container. For this training image the optional control interface is not used, so `--no-control-socket` prevents the warning while keeping access and error logs intact.

## 3. Chapter 6 → Gunicorn command for the HPA test image

**Find:** `CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]`

**Replace with:** `CMD ["gunicorn", "--no-control-socket", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]`

The Chapter 6 image retains the deliberately configured single worker and two threads for its CPU workload exercise. The hardened Chapter 7 v2.3.0 Dockerfile in the repository has been returned to the basic Gunicorn command, as required by Chapter 7's “Do not retain the lab-specific single-worker configuration.”

## 4. Chapters 9 and 10 → companion-path note

**Chapter 9 find:** `From chapter-09/, create the starter structure:`

**Add directly after:**

> These instructions build the chart from scratch within the book's `chapter-09/` working directory. If you use the optional companion repository instead, the completed chart is `helm/flask-app/`; the development and production overrides are `helm/values-development.yaml` and `helm/values-production.yaml`. Run Helm commands from the repository root, for example `helm lint helm/flask-app -f helm/values-development.yaml`. Do not mix the manuscript's reader-built paths with the companion's paths in one command.

**Chapter 10 find:** `From the directory containing chapter-09/ and chapter-10/, lint and render:`

**Add directly after:**

> The book's self-built `chapter-09/` and `chapter-10/` paths differ from the ready-made companion layout. From the companion repository root, use `helm/flask-app` for the chart and `eks/values-eks.yaml` for the environment overrides. The optional guarded AWS validation scripts are documented under `validation/aws-live/`.

## 5. Chapter 10 → AWS tooling/version precondition

**Find:** `Verify it:` immediately before `$ eksctl version` in §10.5.

**Add after the `eksctl version` command:**

> For the EKS Auto Mode lab, verify `eksctl` is at least v0.215.0 and that the shell uses the intended executable. Run `type -a eksctl` (or `which eksctl`) if a newly installed release still reports an older version. Refresh the shell command cache with `hash -r` after fixing the PATH; this does not upgrade an outdated binary.

## 6. Chapter 10 → Metrics Server recovery

**Find:** `ACTIVE confirms the AWS lifecycle state, not functional metrics collection.`

**After the complete metrics-verification paragraph, add:**

> During a new EKS Auto Mode cluster's first capacity allocation, Metrics Server may temporarily report `DEGRADED` with `InsufficientNumberOfReplicas` because no suitable node is ready. Inspect `aws eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server --query 'addon.{status:status,issues:health.issues}' --output json`, check `kubectl get pods -n kube-system -o wide`, and allow a bounded recovery period. Do not reinstall the add-on solely because its initial state is `DEGRADED`. Continue only when the add-on is `ACTIVE`, `kubectl top pods -n flask` returns metrics, and the HPA reports valid CPU metrics.

## 7. Chapter 10 → secure ALB access (important)

**Find** the IngressClassParams listing in §10.9 ending in:

```
spec:
  scheme: internet-facing
  targetType: ip
```

**Add underneath the listing, before the `kubectl apply` steps:**

> Before applying an internet-facing ALB configuration, restrict `spec.inboundCIDRs` to the approved IPv4 source from which you will run the HTTP tests, for example `inboundCIDRs: ["YOUR_PUBLIC_IPV4/32"]` with the placeholder replaced by your actual publicly routable IPv4 address. Verify the egress IP with `curl -4fsS https://checkip.amazonaws.com` and use a single `/32` host route for this lab. Never apply the literal placeholder or use `0.0.0.0/0` as a shortcut. The companion AWS script generates a restricted, account-specific IngressClassParams locally without committing it to Git. Confirm the allowlist before testing external HTTP.

The source YAML under `eks/` remains a generic illustrative template. The live harness generates the safe, operator-specific manifest at runtime.

## 8. Chapter 12 → topology-spread evidence boundary

**Find:** `Placement is verified from observed Pods and nodes, not merely from the presence of the manifest field.`

**Add after:**

> `whenUnsatisfiable: ScheduleAnyway` expresses a scheduling preference, not a multi-zone guarantee. During the November 2026 EKS test, nodes existed in eu-west-2b and eu-west-2c, but all three Flask replicas were scheduled onto one node. The capstone therefore proved Pod replacement, not recovery from loss of that node or an Availability Zone. Record actual Pod-to-node-to-zone placement before claiming multi-AZ availability; a PDB controls voluntary evictions, whereas ordinary Pod deletion does not test that protection.

## 9. Chapter 12 → Helm 4 rollback note

**Find:** `A production-style release needs a documented application rollback path.` (§12.12).

**Add after the section's rollback discussion:**

> When testing a deliberately failed Helm upgrade, Helm 4 uses `helm upgrade --rollback-on-failure`; Helm 3 uses `--atomic`. The November 2026 exercise deliberately failed a rollout, then confirmed a newly deployed rollback revision and successful external ALB requests. A passing rollback command is not sufficient by itself: verify the restored image, Pod readiness and external request path.

Do not run a global `--atomic` replacement on the manuscript: the supplied text does **not** contain that flag. The replacement is required in the AWS validation script, which is included in the repository overlay.

## 10. Appendix F → accuracy of validation claim

**Find:** `The practical workflow was validated end to end using the versions listed above.`

**Replace with:**

> The core Docker, Minikube, Helm and EKS application path was validated through real builds, deployments, network requests, controlled Pod recovery and Helm rollback using the recorded baseline. Optional load-driven HPA scale-out, PDB-enforced eviction, multi-node/multi-AZ failure recovery and the full set of EKS security exercises require separate live evidence. Verify current tool and cloud support before repeating the labs.

## Script-only correction — no Word edit required

`validation/06-health-hpa.sh`, `validation/lib.sh` and the new `validation/configmap-owner.py` repair the historical ConfigMap ownership-marker problem without relaxing same-name object protection. Offline regression cases passed. The optional `K8S_HPA_LOAD=1` **scale-out test has not yet been rerun live**. Do not label it as complete in the book or repository.
