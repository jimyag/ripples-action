# ripples-action

Run [Ripples](https://github.com/jimyag/ripples) on a Go pull request and expose its affected packages as GitHub Actions outputs. Optionally maintain one PR comment listing affected `main` packages.

```yaml
name: Impact
on: pull_request

permissions:
  contents: read
  pull-requests: write # Required only when comment is true.

jobs:
  impact:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: actions/setup-go@v7
        with:
          go-version-file: go.mod
      - id: impact
        uses: jimyag/ripples-action@main
        with:
          base-sha: ${{ github.event.pull_request.base.sha }}
          head-sha: ${{ github.event.pull_request.head.sha }}
          comment: ${{ github.event.pull_request.head.repo.full_name == github.repository }}
          github-token: ${{ github.token }}
      - name: Use affected packages
        env:
          PACKAGES: ${{ steps.impact.outputs.packages }}
          MAINS: ${{ steps.impact.outputs.mains }}
        run: |
          echo "$PACKAGES"
          echo "$MAINS"
```

The action sets three outputs:

| Output | Value |
| --- | --- |
| `packages` | JSON array of affected packages, for example `["cmd/server.main","payment.payment"]` |
| `mains` | JSON array of affected `main` packages, for example `["cmd/server.main"]` |
| `has-changes` | `true` or `false`; counts non-deleted packages |

Use `fromJSON(steps.impact.outputs.mains)` when passing the list to a matrix. Both arrays contain `<relative-path>.<package-name>` and omit deleted packages. An empty result is `[]`. Analysis failures fail the action; they do not produce empty outputs.

The caller must check out both commits (`fetch-depth: 0`) and provide a Go toolchain compatible with the target module. The action currently supports Linux amd64 and arm64 runners and downloads the pinned Ripples release binary with checksum verification. Set `repo-path` for a module below the Git root, or `ripples-version` to select another release.

When `comment` is `true`, pass `github-token` with `pull-requests: write`. A normal `pull_request` workflow from a fork generally receives a read-only token, so the example publishes comments only for same-repository PRs. It still computes outputs for fork PRs. Do not run untrusted PR code with a write token via `pull_request_target`.

The example tracks `main`. Pin a commit SHA or a release tag when you need a fixed action version.
