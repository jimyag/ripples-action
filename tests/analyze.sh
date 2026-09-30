#!/usr/bin/env bash
set -euo pipefail

action_path=$(cd "$(dirname "$0")/.." && pwd)
workdir=$(mktemp -d)
trap 'rm -r "$workdir"' EXIT
mkdir "$workdir/bin"

cat > "$workdir/bin/uname" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case $1 in
  -s) echo Linux ;;
  -m) echo x86_64 ;;
  *) exit 1 ;;
esac
SH
cat > "$workdir/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
url=$4
destination=$6
case $url in
  "https://github.com/jimyag/ripples/releases/download/$EXPECTED_VERSION/ripples_linux_amd64")
    cat > "$destination" <<'BINARY'
#!/usr/bin/env bash
set -euo pipefail
[[ $* == '-repo . -old base -new head -output json' ]]
echo '[{"path":"cmd/server","name":"main"}]'
BINARY
    ;;
  "https://github.com/jimyag/ripples/releases/download/$EXPECTED_VERSION/checksums.txt")
    cd "$(dirname "$destination")"
    sha256sum ripples_linux_amd64 > "$destination"
    ;;
  *) echo "unexpected release URL: $url" >&2; exit 1 ;;
esac
SH
chmod +x "$workdir/bin/uname" "$workdir/bin/curl"
export PATH="$workdir/bin:$PATH"
export GITHUB_ACTION_PATH="$action_path"
export BASE_SHA=base HEAD_SHA=head REPO_PATH=.

# Exercise both the default download and an explicitly selected release.
for version in v0.3.1 v0.3.0; do
  if [[ $version == v0.3.1 ]]; then
    unset RIPPLES_VERSION
  else
    export RIPPLES_VERSION=$version
  fi
  EXPECTED_VERSION=$version GITHUB_OUTPUT="$workdir/$version.outputs" \
    bash "$action_path/scripts/analyze.sh" > /dev/null
  grep -Fxq 'mains=["cmd/server.main"]' "$workdir/$version.outputs"
done
