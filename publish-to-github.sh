#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
OWNER=vebai
NAME=kubernetes-in-practice
FULL="$OWNER/$NAME"
command -v gh >/dev/null || { echo 'Install GitHub CLI (gh) first.' >&2; exit 1; }
command -v git >/dev/null || { echo 'Install Git first.' >&2; exit 1; }
gh auth status >/dev/null || { echo 'Run gh auth login first.' >&2; exit 1; }
LOGIN=$(gh api user --jq .login)
if [[ "$LOGIN" != "$OWNER" ]]; then
  echo "Authenticated as $LOGIN; expected $OWNER. Switch GitHub accounts before publishing." >&2
  exit 1
fi
if gh repo view "$FULL" >/dev/null 2>&1; then
  echo "Repository $FULL already exists. This script will not overwrite it." >&2
  exit 1
fi
if [[ -d .git ]]; then
  echo 'A Git repository already exists here. Publish manually after reviewing git status.' >&2
  exit 1
fi
bash tests/validate-files.sh
printf '\nThis will create PUBLIC GitHub repository %s and push files.\n' "$FULL"
read -r -p 'Type PUBLISH to continue: ' ANSWER
[[ "$ANSWER" == 'PUBLISH' ]] || { echo 'Cancelled.'; exit 0; }
git init -b main
git add .
git diff --cached --check
git commit -m 'Add reader-focused Kubernetes in Practice companion labs'
gh repo create "$FULL" --public --source=. --remote=origin --push
echo "Published: https://github.com/$FULL"
