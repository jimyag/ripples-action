#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
impact_json=${1:?impact JSON path is required}

packages=$(jq -c '[.[] | select(.deleted != true) | "\(.path).\(.name)"]' "$impact_json")
mains=$(jq -c '[.[] | select(.deleted != true and .name == "main") | "\(.path).\(.name)"]' "$impact_json")

if [[ $packages == '[]' ]]; then
  has_changes=false
else
  has_changes=true
fi

{
  printf 'packages=%s\n' "$packages"
  printf 'mains=%s\n' "$mains"
  printf 'has-changes=%s\n' "$has_changes"
} >> "$GITHUB_OUTPUT"

printf 'Affected packages: %s\nAffected main packages: %s\n' "$packages" "$mains"
