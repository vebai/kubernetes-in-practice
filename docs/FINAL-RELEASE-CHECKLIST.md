# Final repository release checklist

Applies to the existing public GitHub repo: https://github.com/vebai/kubernetes-in-practice

## 1. Preserve the current checkout

From your Mac terminal:

```bash
cd ~/kubernetes-in-practice
git remote -v
git branch --show-current
git status --short
```

If the checkout has unrelated uncommitted work, protect it first and inspect the differences. Do not use `git reset --hard`, `git clean -fdx`, or the repository's `publish-to-github.sh`: the latter creates a NEW repository and intentionally refuses an existing one.

## 2. Install the final overlay

Extract `kubernetes-in-practice-final-repo-overlay-20261105.zip` into the repository root. It contains only the final test harness, four Dockerfiles and new documentation. It does **not** contain the original repo's complete source or edit the Word manuscript.

```bash
unzip -o ~/Downloads/kubernetes-in-practice-final-repo-overlay-20261105.zip -d .
python3 validation/apply-repo-docs.py
python3 validation/apply-repo-docs.py --apply
```

The documentation patcher first checks every expected anchor before changing any file. It is idempotent; when an anchor differs due to manual edits, it stops without rewriting files.

## 3. Offline QA and optional image smoke

```bash
python3 validation/test-configmap-owner.py
python3 validation/test-final-maintenance.py
bash tests/validate-files.sh
bash validation/preflight.sh
```

`preflight.sh` also requires local Docker and Kubernetes tooling plus PyYAML; it does not provision any AWS resources. It does not repeat the completed EKS deployment.

The Dockerfiles changed after the live EKS validation to disable Gunicorn's optional control socket; `v2.3.0` also returns to the ordinary worker settings described in the book. Before claiming these final image edits live-tested, build and run a new local image:

```bash
docker build -t flask-app:v2.3.0 ./flask-app/versions/v2.3.0
docker run --rm -d --name book-final-smoke -p 127.0.0.1:5051:5000 flask-app:v2.3.0
curl --fail http://127.0.0.1:5051/healthz
docker logs book-final-smoke
docker stop book-final-smoke
```

If a container with the smoke-test name exists, inspect ownership before recreating it. The successful response should include `{"status":"alive"}` and startup should have no Gunicorn control-socket permission error.

## 4. Review and stage only intended repository material

```bash
git status --short
git diff --check
git ls-files validation/.logs/
git check-ignore -v validation/.logs/aws-live/kubeconfig
```

The `git ls-files validation/.logs/` check must be empty. Never commit `.logs/`, isolated kubeconfigs, AWS API endpoints, account-specific registry values, access tokens, private keys, AWS billing reports or generated data.

Stage only the final new/modified source and docs. For example:

```bash
git add .gitignore README.md \
  docs/VALIDATION-EVIDENCE.md docs/REPO-BOOK-PATHS.md \
  docs/BOOK-MANUAL-FIND-REPLACE.md docs/FINAL-RELEASE-CHECKLIST.md \
  docs/CLEANUP.md docs/EKS-SAFETY.md docs/SETUP.md \
  chapters/chapter-10-eks/README.md \
  chapters/chapter-11-eks-operations/README.md \
  chapters/chapter-12-final-project/README.md \
  flask-app/Dockerfile \
  flask-app/versions/v2.1.0/Dockerfile \
  flask-app/versions/v2.2.0/Dockerfile \
  flask-app/versions/v2.3.0/Dockerfile \
  validation/

git diff --cached --stat
git diff --cached --check
bash validation/repo-release-audit.sh
```

Review `git diff --cached` before the next step. If a sensitive file is staged, unstage that individual path with `git restore --staged -- PATH` and investigate.

## 5. Commit and push the existing main branch

```bash
git commit -m "Finalise validated Kubernetes and EKS companion labs"
git push origin main
git status --short
git rev-parse --short HEAD
```

The hosted repository should show `validation/README.md`, `validation/aws-live/README.md`, the updated Dockerfiles, the evidence report, and reconciliation docs. **Do not** use `publish-to-github.sh` for this already-created public repo.

## 6. Clean up local clusters only if no longer needed

Cloud EKS, ECR and ALB deletion was independently verified on 5 November 2026. Additional AWS NAT/EC2/EIP checks were recommended but were not provided as evidence at the time of this report. Locally, keep logs while final QA continues. If both named profiles are owned only by this lab and you have no need for them:

```bash
minikube profile list
minikube delete -p book-k8s-security
minikube delete -p book-k8s-validation
```

Do not delete the profile named `minikube` or the manuscript's manually created `security-lab` without checking what they contain. Profile deletion is optional, not required for Git publishing.

## 7. Update Word manually

Use `docs/BOOK-MANUAL-FIND-REPLACE.md` to apply the targeted edits to the manuscript. No `.docx` modification is included in this overlay. After editing, update Word's TOC, verify page breaks, figure/table placement and page numbers, then export KDP and ebook files separately as needed.
