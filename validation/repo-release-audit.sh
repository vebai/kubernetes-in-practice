#!/usr/bin/env bash
# Pre-push checks. No file mutation, no AWS changes and no Git commits/pushes.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
[[ -d .git ]] || { echo '[BLOCKED] Not a Git checkout'; exit 2; }
[[ "$(git branch --show-current)" == main ]] || { echo '[BLOCKED] This publishing checklist expects branch main'; exit 2; }
branch_url="$(git remote get-url origin)"
case "$branch_url" in
  *github.com/vebai/kubernetes-in-practice.git|*github.com:vebai/kubernetes-in-practice.git) ;;
  *) echo "[BLOCKED] Unexpected origin remote: $branch_url"; exit 2;;
esac
tracked_sensitive="$(git ls-files -- 'validation/.logs/**' 'validation/.logs/*' '*.pem' '*.key' '*.p12' '*kubeconfig*' '*.tfstate*')"
if [[ -n "$tracked_sensitive" ]]; then
  printf '[BLOCKED] Sensitive runtime paths are already tracked:\n%s\n' "$tracked_sensitive" >&2
  exit 2
fi
git check-ignore -q validation/.logs/aws-live/kubeconfig || {
  echo '[BLOCKED] Generated AWS kubeconfig would not be Git-ignored' >&2; exit 2;
}
git diff --cached --check
if git grep --cached -nE '(AKIA|ASIA)[A-Z0-9]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----' -- . ':!validation/repo-release-audit.sh' >/dev/null 2>&1; then
  echo '[BLOCKED] Possible cloud credentials or private keys in staged content; inspect before committing.' >&2
  exit 2
fi
printf '\n[OK] Remote, branch, tracked-file hygiene, ignore rules, staged whitespace and common credential markers.\n'
printf '[INFO] Review these staged paths before committing:\n'
git diff --cached --name-only
