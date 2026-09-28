#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?github-token is required when comment is true}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_EVENT_PATH:?GITHUB_EVENT_PATH is required}"
: "${MAINS_JSON:?MAINS_JSON is required}"

pr_number=$(jq -r '.pull_request.number // empty' "$GITHUB_EVENT_PATH")
if [[ -z $pr_number ]]; then
  echo 'comment requires a pull request event' >&2
  exit 1
fi

workdir=$(mktemp -d)
trap 'rm -r "$workdir"' EXIT
body_file="$workdir/body.md"
{
  printf '<!-- ripples-action -->\n### Affected main packages\n\n'
  if [[ $MAINS_JSON == '[]' ]]; then
    printf 'None.\n'
  else
    jq -r '.[] | "- `\(.)`"' <<< "$MAINS_JSON"
  fi
} > "$body_file"
jq -n --rawfile body "$body_file" '{body: $body}' > "$workdir/payload.json"

endpoint="repos/$GITHUB_REPOSITORY/issues/$pr_number/comments"
comment_id=$(gh api "$endpoint" --paginate --jq '.[] | select(.user.login == "github-actions[bot]" and (.body | startswith("<!-- ripples-action -->"))) | .id' | tail -n 1)
if [[ -n $comment_id ]]; then
  gh api --method PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$comment_id" --input "$workdir/payload.json" > /dev/null
else
  gh api --method POST "$endpoint" --input "$workdir/payload.json" > /dev/null
fi
