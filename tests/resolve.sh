#!/usr/bin/env bash
set -euo pipefail

workdir=$(mktemp -d)
trap 'rm -r "$workdir"' EXIT

cat > "$workdir/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat "$PR_LIST"
SH
chmod +x "$workdir/gh"

export PATH="$workdir:$PATH"
export GH_TOKEN=test-token
export GITHUB_REPOSITORY=example/project
export GITHUB_EVENT_PATH="$workdir/event.json"
export RUN_HEAD_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
export RUN_HEAD_REPO_ID=42
export PR_LIST="$workdir/prs.json"

cat > "$GITHUB_EVENT_PATH" <<'JSON'
{"workflow_run":{"event":"pull_request","conclusion":"success","repository":{"full_name":"example/project"}}}
JSON

cat > "$PR_LIST" <<'JSON'
[
  {"number":7,"head":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","repo":{"id":42}},"base":{"sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  {"number":8,"head":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","repo":{"id":99}},"base":{"sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}
]
JSON
GITHUB_OUTPUT="$workdir/outputs" bash "$(dirname "$0")/../scripts/resolve.sh" > /dev/null
grep -Fxq 'found=true' "$workdir/outputs"
grep -Fxq 'number=7' "$workdir/outputs"
grep -Fxq 'base-sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' "$workdir/outputs"

RUN_HEAD_SHA=cccccccccccccccccccccccccccccccccccccccc GITHUB_OUTPUT="$workdir/stale" \
  bash "$(dirname "$0")/../scripts/resolve.sh" > /dev/null
grep -Fxq 'found=false' "$workdir/stale"

cat > "$GITHUB_EVENT_PATH" <<'JSON'
{"workflow_run":{"event":"push","conclusion":"success","repository":{"full_name":"example/project"}}}
JSON
if GITHUB_OUTPUT="$workdir/invalid" bash "$(dirname "$0")/../scripts/resolve.sh" > /dev/null 2>&1; then
  echo 'non-PR workflow run was accepted' >&2
  exit 1
fi
