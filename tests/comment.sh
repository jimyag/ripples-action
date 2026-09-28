#!/usr/bin/env bash
set -euo pipefail

workdir=$(mktemp -d)
trap 'rm -r "$workdir"' EXIT

cat > "$workdir/event.json" <<'JSON'
{"pull_request":{"number":42}}
JSON
cat > "$workdir/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ " $* " == *' --paginate '* ]]; then
  printf '%s\n' "${EXISTING_COMMENT_ID:-}"
  exit 0
fi

printf '%s\n' "$*" >> "$GH_CALLS"
while [[ $# -gt 0 ]]; do
  if [[ $1 == --input ]]; then
    jq -e '.body | startswith("<!-- ripples-action -->") and contains("cmd/server.main")' "$2" > /dev/null
    break
  fi
  shift
done
SH
chmod +x "$workdir/gh"

export PATH="$workdir:$PATH"
export GH_TOKEN=test-token
export GITHUB_REPOSITORY=example/project
export GITHUB_EVENT_PATH="$workdir/event.json"
export MAINS_JSON='["cmd/server.main"]'
export GH_CALLS="$workdir/calls"

bash "$(dirname "$0")/../scripts/comment.sh"
grep -Fq -- '--method POST repos/example/project/issues/42/comments' "$GH_CALLS"

: > "$GH_CALLS"
EXISTING_COMMENT_ID=123 bash "$(dirname "$0")/../scripts/comment.sh"
grep -Fq -- '--method PATCH repos/example/project/issues/comments/123' "$GH_CALLS"
