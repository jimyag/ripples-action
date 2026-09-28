#!/usr/bin/env bash
set -euo pipefail

workdir=$(mktemp -d)
trap 'rm -r "$workdir"' EXIT

cat > "$workdir/impact.json" <<'JSON'
[
  {"path":"cmd/server","name":"main"},
  {"path":"payment","name":"payment"},
  {"path":"cmd/old","name":"main","deleted":true}
]
JSON

GITHUB_OUTPUT="$workdir/outputs" bash "$(dirname "$0")/../scripts/outputs.sh" "$workdir/impact.json" > /dev/null
grep -Fxq 'packages=["cmd/server.main","payment.payment"]' "$workdir/outputs"
grep -Fxq 'mains=["cmd/server.main"]' "$workdir/outputs"
grep -Fxq 'has-changes=true' "$workdir/outputs"

printf '[]\n' > "$workdir/empty.json"
GITHUB_OUTPUT="$workdir/empty-outputs" bash "$(dirname "$0")/../scripts/outputs.sh" "$workdir/empty.json" > /dev/null
grep -Fxq 'packages=[]' "$workdir/empty-outputs"
grep -Fxq 'mains=[]' "$workdir/empty-outputs"
grep -Fxq 'has-changes=false' "$workdir/empty-outputs"
