# Chapter 12 — Production-style Kubernetes deployment

**Goal:** Prove the complete request path, inspect HPA and PDB controls, observe workload recovery, and prepare evidence for a safe release or rollback.

**Prerequisites:** You already deployed Chapter 10's Helm release in the intended EKS account/Region. Confirm the active Kubernetes context and ECR image before making changes; read [EKS safety](../../docs/EKS-SAFETY.md) first.

From the repository root:

```bash
aws sts get-caller-identity
kubectl config current-context
helm list -n flask
kubectl get deployment,service,ingress,hpa,pdb -n flask
kubectl get pods -n flask -o wide
```

[`eks/values-capstone.yaml`](../../eks/values-capstone.yaml) adds capstone replica, resource, availability and topology-spread settings. Replace `REPLACE_WITH_ECR_REGISTRY` with your own image registry in a **local** copy. The chart implements `topologySpread.enabled` as an optional feature so local Helm exercises remain compatible.

**Check before applying:**

```bash
helm lint helm/flask-app -f eks/values-capstone.yaml
helm template flask-app helm/flask-app -n flask -f eks/values-capstone.yaml > /tmp/flask-capstone.yaml
helm history flask-app -n flask
```

Only after reviewing the rendered release and confirming costs, quotas and desired capacity should you use `helm upgrade --install ... --wait`. Verify rollout and ALB traffic, then inspect HPA, PDB, Pod scheduling and logs. A cluster may require multiple AZs and sufficient capacity to meet your intended distribution and disruption objectives.

**Controlled recovery:** after taking note of the current release revision, inspect rollout history, deliberately remove **one lab-owned Pod**, and verify a replacement appears and the application's HTTP endpoint still works. Do not delete nodes or cluster resources to simulate a failure.

```bash
kubectl get pods -n flask
kubectl rollout status deployment/flask-app -n flask
helm history flask-app -n flask
```

If a new release is faulty, review revision history and roll back to the intended previous revision using `helm rollback flask-app REVISION -n flask --wait --timeout 10m`, then repeat application and readiness checks. Do not copy a revision number from a different environment.

**Finish with AWS cleanup**: [Remove the workload, inspect ALBs, then remove the cluster and lab ECR repository](../../docs/CLEANUP.md). EKS billing can continue until cleanup is confirmed.
