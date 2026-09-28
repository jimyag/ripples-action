#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GitHub token is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_EVENT_PATH:?GITHUB_EVENT_PATH is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${RUN_HEAD_SHA:?workflow run head SHA is required}"
: "${RUN_HEAD_REPO_ID:?workflow run head repository ID is required}"

if [[ ! $RUN_HEAD_SHA =~ ^[0-9a-f]{40}$ || ! $RUN_HEAD_REPO_ID =~ ^[0-9]+$ ]]; then
  echo 'invalid workflow run head identity' >&2
  exit 1
fi
if ! jq -e --arg repository "$GITHUB_REPOSITORY" \
  '.workflow_run.event == "pull_request" and .workflow_run.conclusion == "success" and .workflow_run.repository.full_name == $repository' \
  "$GITHUB_EVENT_PATH" > /dev/null; then
  echo 'expected a successful pull request workflow run in this repository' >&2
  exit 1
fi

matches=$(gh api "repos/$GITHUB_REPOSITORY/pulls?state=open&per_page=100" --paginate |
  jq -sc --arg sha "$RUN_HEAD_SHA" --argjson repo_id "$RUN_HEAD_REPO_ID" \
    '[.[][] | select(.head.sha == $sha and .head.repo.id == $repo_id) | {number, base_sha: .base.sha, head_sha: .head.sha}]')

count=$(jq 'length' <<< "$matches")
case $count in
  0)
    echo 'found=false' >> "$GITHUB_OUTPUT"
    echo 'No open PR matches this workflow run; skipping stale result.'
    ;;
  1)
    jq -r '.[0] | "found=true\nnumber=\(.number)\nbase-sha=\(.base_sha)\nhead-sha=\(.head_sha)"' <<< "$matches" >> "$GITHUB_OUTPUT"
    ;;
  *)
    echo "multiple open PRs match this workflow run: $count" >&2
    exit 1
    ;;
esac
