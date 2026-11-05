#!/usr/bin/env python3
"""Apply constrained, idempotent final documentation fixes to the existing repo.

Default: validate and list candidate changes only. Use --apply to edit local
repository docs; never touches the Word manuscript, Git history, or AWS.
"""
import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent


def insert_once(content, anchor, extra):
    if extra in content:
        return content
    if content.count(anchor) != 1:
        raise ValueError(f'unique anchor not found: {anchor[:90]!r}')
    return content.replace(anchor, anchor + extra, 1)


def replace_once(content, before, after):
    if after in content:
        return content
    if content.count(before) != 1:
        raise ValueError(f'unique replacement anchor not found: {before[:90]!r}')
    return content.replace(before, after, 1)


def edit(path, text):
    if path == 'README.md':
        text = replace_once(
            text,
            '**Separate security lab (Chapter 7).** Uses its own `security-lab` Minikube profile and `shop` namespace so you can practise NetworkPolicy without disrupting the earlier cluster.',
            '**Separate security lab (Chapter 7).** The manual book lab uses `security-lab`; the automated validation uses a distinct `book-k8s-security` Minikube profile and the `shop` namespace, with Calico enforcement. Do not mix the two contexts.'
        )
        text = insert_once(text, '## Verification, troubleshooting and cleanup',
            '\n\nThe optional [chapter validation suite](validation/README.md) and [staged AWS live-validation suite](validation/aws-live/README.md) have separate execution boundaries. Read [what was actually tested](docs/VALIDATION-EVIDENCE.md) and the [book-to-repo path map](docs/REPO-BOOK-PATHS.md). A locally rendered EKS chart does not prove a live EKS cluster. EKS creation, deliberate faults and deletion each require explicit approval.\n')
    elif path == 'docs/CLEANUP.md':
        text = replace_once(text, 'minikube delete -p security-lab', 'minikube delete -p book-k8s-security')
        text = insert_once(text, 'This removes the **dedicated** Chapter 7 profile.',
            ' The book\'s separate hand-built lab may instead use `security-lab`; delete only the profile you actually created. The automated suite also uses `book-k8s-validation` for its main local profile.')
        text = insert_once(text, 'Deleting a Kubernetes workload does not automatically mean the cluster, ECR repository or every load balancer has been deleted.',
            ' The author independently checked EKS, ECR, ELBv2 and CloudFormation after the November 2026 lab, but also recommends reviewing NAT gateways, EC2 instances, elastic IPs, ENIs, VPCs and delayed billing before declaring costs finished.')
    elif path == 'docs/SETUP.md':
        text = replace_once(text, '## General rules',
            '## Optional chapter-by-chapter validation\n\nThe manual book labs and the repository automated harness are alternative routes. For the harness, use the distinct `book-k8s-validation` and `book-k8s-security` profiles, check Docker Desktop capacity and run `bash validation/preflight.sh` followed by `bash validation/run.sh 01` from the repository root. For the AWS live path, see `validation/aws-live/README.md`; the local harness never creates AWS resources.\n\n## General rules')
    elif path == 'docs/EKS-SAFETY.md':
        text = insert_once(text, 'Keep your AWS CLI human identity and Kubernetes workload permissions separate.',
            ' The tested live path restricts the public ALB ingress to an approved single public IPv4 `/32`; never assume a wildcard internet-facing ALB is restricted. An initially `DEGRADED` Metrics Server add-on can reflect pending node capacity; inspect health issues and give bounded time for recovery before making a change.')
    elif path == 'chapters/chapter-10-eks/README.md':
        text += '' if '## Optional tested automation path' in text else '''\n\n## Optional tested automation path\n\nThe manual book exercise above is self-contained. If you use the **companion** files instead, keep the repository root as the working directory: the chart is `helm/flask-app`, the EKS override is `eks/values-eks.yaml`, and the cluster source is `eks/cluster.yaml`. Use `validation/aws-live/00-preflight.sh` for read-only checks and the staged scripts in `validation/aws-live/README.md` for expressly authorised, chargeable deployment and cleanup. The tested process overrides `image.repository` with the actual ECR URI through Helm `--set-string`; it does not require committing a personal registry address into `values-eks.yaml`. The live script also generates a per-operator restricted ALB `inboundCIDRs` manifest in ignored local state. During initial Auto Mode capacity provisioning, Metrics Server may report `DEGRADED` transiently; inspect `health.issues` and wait within defined limits rather than immediately reinstalling the add-on.\n'''
    elif path == 'chapters/chapter-11-eks-operations/README.md':
        text += '' if '## Verified live operations evidence' in text else '''\n\n## Verified live operations evidence\n\nOn 5 November 2026 the author verified healthy ALB target groups, an external HTTP response, real CPU metrics and HPA `ScalingActive` on a live EKS Auto Mode cluster. Two Ready nodes existed in separate AZs, but **both Flask application Pods ran on one node**. Platform node spread is not application spread. The separate read-only runner is `bash validation/aws-live/11-observe.sh`; it requires the isolated kubeconfig and exact AWS account used by the creation stage. See `docs/VALIDATION-EVIDENCE.md` for limits.\n'''
    elif path == 'chapters/chapter-12-final-project/README.md':
        text += '' if '## Live capstone evidence and limitations' in text else '''\n\n## Live capstone evidence and limitations\n\nThe author validated a real Helm upgrade to three replicas, recovery after deleting a single owned Pod, a deliberately broken image upgrade, Helm automatic rollback, and healthy external ALB traffic after both recoveries. Helm 4 uses `--rollback-on-failure` (Helm 3 uses `--atomic`). The live capstone's three Pods nevertheless remained on **one worker node**. `ScheduleAnyway` is only a scheduling preference and does not prove multi-AZ placement; a Pod deletion does not prove PDB-enforced eviction. Load-driven HPA scale-out, node/AZ loss and EKS NetworkPolicy enforcement were not covered by the automated capstone. See `docs/VALIDATION-EVIDENCE.md`.\n'''
    elif path == '.gitignore':
        text = insert_once(text, '*.tfstate*', '\nvalidation/.logs/\n.validation-venv/\n')
    else:
        raise ValueError('unexpected path')
    return text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true', help='write the checked local documentation updates')
    args = ap.parse_args()
    paths = ['README.md', '.gitignore', 'docs/CLEANUP.md', 'docs/SETUP.md', 'docs/EKS-SAFETY.md',
             'chapters/chapter-10-eks/README.md', 'chapters/chapter-11-eks-operations/README.md',
             'chapters/chapter-12-final-project/README.md']
    staged = {}
    for relative in paths:
        path = ROOT / relative
        try:
            old = path.read_text(encoding='utf8')
            new = edit(relative, old)
        except (OSError, ValueError) as exc:
            print(f'[BLOCKED] {relative}: {exc}', file=sys.stderr)
            return 1
        staged[path] = (old, new)
    for path, (old, new) in staged.items():
        status = 'UPDATE' if old != new else 'UNCHANGED'
        print(f'{status}: {path.relative_to(ROOT)}')
    if args.apply:
        for path, (old, new) in staged.items():
            if old != new:
                path.write_text(new, encoding='utf8')
        print('Local documentation updates applied. Review git diff; Word manuscript unchanged.')
    else:
        print('DRY RUN: no files changed. Add --apply to apply these updates to local repository documents.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
