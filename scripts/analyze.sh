#!/usr/bin/env bash
set -euo pipefail

: "${BASE_SHA:?base-sha is required}"
: "${HEAD_SHA:?head-sha is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) asset=ripples_linux_amd64 ;;
  Linux-aarch64) asset=ripples_linux_arm64 ;;
  *) echo "unsupported runner architecture: $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

version=${RIPPLES_VERSION:-v0.3.1}
if [[ ! $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid ripples-version: $version" >&2
  exit 1
fi

workdir=$(mktemp -d)
trap 'rm -r "$workdir"' EXIT
release_url="https://github.com/jimyag/ripples/releases/download/$version"
curl -fsSL --retry 3 "$release_url/$asset" -o "$workdir/$asset"
curl -fsSL --retry 3 "$release_url/checksums.txt" -o "$workdir/checksums.txt"
(
  cd "$workdir"
  sha256sum --check --ignore-missing checksums.txt
)
chmod +x "$workdir/$asset"

"$workdir/$asset" -repo "${REPO_PATH:-.}" -old "$BASE_SHA" -new "$HEAD_SHA" -output json > "$workdir/impact.json"
bash "$GITHUB_ACTION_PATH/scripts/outputs.sh" "$workdir/impact.json"
