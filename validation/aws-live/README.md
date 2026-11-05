# Kubernetes in Practice — AWS EKS LIVE validation pack

This **separate** overlay installs under `validation/aws-live/` at the root of the existing companion repository. It leaves the successful local `validation/` scripts and the book's source files unchanged. It was assembled from the actual `eks/` and `helm/flask-app/` files in the public repository.

**Operating rule:** One script per stage. Stop on any unexpected failure. Retain the cluster and logs for diagnosis. Never delete an unverified cluster to 'fix' a script failure. These scripts have undergone local syntax/fixture checks, **not a real AWS live test**.

## Before any billable step

Use an authorised, non-production account. Verify an AWS Budget alert and an AWS Pricing Calculator estimate for your intended run time. EKS costs include a cluster-hour charge ($0.10/hour for version 1.36 in standard support), EC2 Auto Mode capacity plus Auto Mode fee, ALB and other network usage, possible NAT gateway hours/data processing, public IPv4 and ECR storage. **Creating a budget does not stop billing.** A failed command can leave billable resources.

The AWS scripts enforce the book's existing baseline: AWS Region `eu-west-2`, cluster `flask-eks`, ECR repository `flask-app`, Kubernetes `1.36`, image tag `v2.3.0`. They do not silently upgrade the book version or create a second cluster under another name.

**Tools:** AWS CLI v2, eksctl, Docker Engine, kubectl, Helm, Python 3, curl, Bash. AWS credentials via AWS SSO or another secure profile; never paste secret access keys. `AWS_PROFILE` is respected.

## Stage 0: account and cost preflight — READ ONLY

From the repository root:

```bash
export AWS_PROFILE=YOUR_EXISTING_PROFILE   # omit if the default identity is correct
export AWS_REGION=eu-west-2
bash validation/aws-live/00-preflight.sh
```

Read the report before going further. It checks tools, STS identity, supported EKS versions, existing clusters and repositories, and Metrics Server add-on compatibility without provisioning AWS resources. Confirm the account ID from the AWS Console. Do not post account IDs or ARNs publicly; redact them in shared logs.

## Stage 10: ECR + EKS Auto Mode + Helm + ALB + Metrics Server — CHARGEABLE

After independently verifying the account, budget and projected cost, identify the **public IPv4 egress address of the machine that will make the ALB HTTP test requests**. A trusted check such as `curl -4 https://checkip.amazonaws.com` can display it; this is not your private `192.168.*` address. If connected through a VPN or proxy, the outbound address may differ. The live script requires exactly one globally routable IPv4 `/32` host route, which limits public HTTP access to your chosen source address. Do not use `0.0.0.0/0`.

The sample repository's `eks/alb-ingress-class-params.yaml` does not specify `inboundCIDRs`; current AWS EKS Workshop guidance warns this can leave an ALB unreachable. The validation pack therefore generates a separate restricted manifest in ignored local logs; it **does not edit the source YAML**. <https://eksworkshop.com/docs/fastpaths/developer/ingress/adding-ingress>

After the above checks:

```bash
export K8S_EXPECTED_AWS_ACCOUNT=123456789012  # REPLACE with real account, not example
export K8S_ALLOWED_CIDR=203.0.113.4/32      # EXAMPLE ONLY: replace with YOUR real public IPv4/32
export K8S_AWS_BUDGET_CONFIRMED=YES
export K8S_AWS_CHARGE_APPROVAL=I_ACCEPT_EKS_CHARGES
bash validation/aws-live/10-create-deploy.sh
```

**CAUTION:** Do not run the stage if `flask-eks` or `flask-app` already exists; the creation script refuses unknown resources. The script creates an immutable ECR repo, builds/pushes the book image, creates the book's EKS Auto Mode cluster, writes an **isolated kubeconfig** under `validation/.logs/aws-live/`, installs the EKS Auto Mode IngressClass with a **restricted** ingress-params manifest generated under `.logs/` using `K8S_ALLOWED_CIDR`, deploys the Helm chart using `--set-string image.repository=...` rather than editing source files, and installs/verifies the `metrics-server` community add-on if needed. Then it requires a real HTTP `/healthz` response from the external ALB.

This step can create an internet-facing endpoint. Use only non-sensitive test data. On any failure, review the failing checkpoint and AWS resources rather than immediately rerunning the create script. The script intentionally does not clean up automatically on failure, to preserve evidence, so billable resources may remain.

## Stage 11: live operations evidence — READ ONLY

```bash
bash validation/aws-live/11-observe.sh
```

Verifies account and EKS API endpoint before reads. Checks ECR digest, EKS Auto Mode, add-ons, Helm revision, nodes, rollout, events, Metrics Server, the HPA's `ScalingActive` condition, ALB target health, and external `/` and `/healthz` HTTP responses.

## Stage 12: capstone recovery — MUTATES LAB ONLY

```bash
export K8S_AWS_FAULT_APPROVAL=I_ACCEPT_CONTROLLED_LAB_FAULTS
bash validation/aws-live/12-capstone.sh
```

Upgrades the Helm release to `eks/values-capstone.yaml`, proves 3 available replicas, HPA minimum 3, PDB minimum 2, zone spread configuration, deletes **one** lab-owned application Pod and requires a different Ready Pod plus healthy ALB HTTP. It then deliberately attempts a broken image upgrade using Helm 4 `--rollback-on-failure` (Helm 3: `--atomic`); this must fail and roll back automatically. The script verifies the original image and ALB health afterwards. This stage is not a proof of HPA *scale-out* under synthetic CPU load, or automatic multi-AZ placement: those require separate resource observations and possibly deliberate load.

**Important:** EKS Auto Mode may not honour the `alb.ingress.kubernetes.io/healthcheck-path` annotation in the example Helm values. Verify the actual ALB target-group HealthCheckPath in Stage 11 instead of assuming `/readyz`. If required, document and repair this as a targeted manuscript/repository correction.

**Important:** The capstone uses `topologySpread.whenUnsatisfiable=ScheduleAnyway`, a preference rather than an absolute multi-AZ guarantee. Check the actual node labels, node count and Pod distribution before describing the release as multi-zone. An abrupt Pod deletion does not prove PDB protection; a PDB governs voluntary evictions using the Eviction API.

## Stage 99: cloud cleanup — DESTRUCTIVE

After collecting evidence, explicitly approve removal. This script accepts **only** the cluster recorded as created by Stage 10 for the same account:

```bash
export K8S_AWS_DELETE_APPROVAL=DELETE_flask-eks_eu-west-2
export K8S_AWS_DELETE_ECR=YES
bash validation/aws-live/99-cleanup.sh
```

It uninstalls the `flask/flask-app` Helm release, waits for the app's ALB to disappear from AWS, removes the dedicated IngressClass/Params, uses `eksctl delete cluster -f eks/cluster.yaml --wait`, and optionally deletes the ECR repository **only** if it carries the pack's ownership marker and has no unexpected image tags. It does **not** blindly delete other cloud assets. Finally inspect CloudFormation, NAT gateways, public IPs, ALBs/target groups, ECR, EC2 and billing. The script refuses deletion if identity, resource ownership or endpoint verification fails.

## Logs and account safety

All logs and the isolated kubeconfig go under `validation/.logs/aws-live/`, which is ignored by the chapter validation Git ignore rule. Retain them locally. Before sharing, redact 12-digit account IDs, EKS API endpoints, ALB DNS, and any sensitive output. Avoid printing or sharing credential values.

**Do not set `KUBECONFIG` globally**: these scripts invoke kubectl/Helm with their own `--kubeconfig` and `--kube-context` flags. They leave Minikube's contexts unchanged. The EKS creation scripts never automatically proceed from the preflight; every mutating stage has an explicit user-controlled approval variable.

## Known limits

The original AWS workflow completed real EKS deployment, ALB, HPA, controlled failure and rollback testing in eu-west-2 on 5 November 2026. The final maintenance changes remain offline-tested, not re-deployed to AWS. It should not be described as a validated EKS implementation merely because shell syntax passes. Cost estimates are not hard-coded because AWS resource choice, AZ placement, networking and run duration affect the final bill. Monitor actual costs and tear down promptly. If any checkpoint fails, send the relevant output; do not run a broad cleanup command on unfamiliar infrastructure.

## Partial failures and safe recovery

If Stage 10 creates an EKS cluster but fails before writing an isolated kubeconfig, use `bash validation/aws-live/09-recover-context.sh`. It verifies the exact account and the local cluster-creation marker before writing a local kubeconfig; it does not mutate AWS. If the cluster is only `CREATING` or failed, inspect **EKS → Clusters** and **CloudFormation → Stacks** before doing anything else.

If Stage 10 creates ECR and stops **before any EKS cluster exists**, verify `aws eks list-clusters --region eu-west-2` and then, if appropriate, run:

```bash
export K8S_AWS_DELETE_ECR_ONLY=DELETE_BOOK_ECR_ONLY
bash validation/aws-live/98-ecr-only-cleanup.sh
```

This refuses deletion if the book cluster exists or the ECR repo contains unexpected image tags. A partial eksctl/CloudFormation creation can still leave other billable resources: always inspect them independently.

## Stage 10 interrupted after EKS was created: read-only resume (v1.3)

If `10-create-deploy.sh` has already created ECR, an ACTIVE cluster and a deployed
Helm release, **do not run it again**. Some newly created EKS Auto Mode clusters
briefly show `metrics-server` as `DEGRADED` while nodes and Pods settle. The initial creation script now uses bounded polling and captures add-on health if it does not recover. The
v1.2 script stopped immediately at that status; it does not prove the add-on
was permanently broken. Use the new resume-only check:

```bash
# Same terminal or re-export the verified 12-digit AWS account ID:
export K8S_EXPECTED_AWS_ACCOUNT=YOUR_APPROVED_ACCOUNT_ID
bash validation/aws-live/10-resume-existing.sh
```

This script verifies the *existing* cluster, matching image and Helm release,
waits up to six minutes for Metrics Server `ACTIVE` and captures AWS add-on
health details plus Kubernetes Pod/APIService logs if it remains unhealthy.
It requires working `kubectl top pods`, HPA `ScalingActive` and `currentMetrics`,
then tests the real ALB `/healthz` and `/` endpoints. **It makes no AWS or
Kubernetes mutations and does not re-create the cluster, ECR or Helm release.**
A pass means continue with `11-observe.sh`; a failure means review the reported
checkpoint while AWS resources continue to incur charges.
