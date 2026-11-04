# Troubleshooting: inspect evidence before changing anything

**First establish where commands are going:**

```bash
kubectl config current-context
kubectl get nodes
kubectl get pods -A
```

**Then narrow the failing layer:**

```bash
kubectl get deployment,service,pods
kubectl describe deployment flask-app
kubectl get events --sort-by=.lastTimestamp
kubectl logs deployment/flask-app --tail=60
kubectl get endpointslices -l kubernetes.io/service-name=flask-app
kubectl rollout status deployment/flask-app
```

If Pods are `Pending`, inspect the scheduler events and resource requests. For `ImagePullBackOff`, check the exact image/tag and whether the image is accessible from **that** cluster. For `CrashLoopBackOff`, inspect `kubectl logs --previous` on the relevant Pod and its exit code. A Service with no endpoints usually points to a label/selector mismatch or unready Pods.

For configuration errors, inspect the referenced ConfigMap/Secret **names and keys** without printing secret values. For NetworkPolicy, confirm your CNI enforces it, the client Pod labels and namespace are correct, and the expected ports are allowed.

Make the smallest justified change, then repeat the original request or readiness check. See [Chapter 8's diagnostic exercise](../chapters/chapter-08-troubleshooting/README.md).

On EKS, also confirm AWS identity/Region, ECR image digest, Ingress controller resources, ALB target health and relevant AWS service quotas before changing infrastructure.
