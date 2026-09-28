# ripples-action

Run [Ripples](https://github.com/jimyag/ripples) on a Go pull request and expose its affected packages as GitHub Actions outputs. A separate trusted workflow can comment on PRs from forks.

## Affected package outputs

```yaml
name: Impact
on: pull_request

permissions:
  contents: read

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

## Comments on fork PRs

Add this second workflow to the base repository. Its `workflows` value must match the first workflow's `name` (`Impact` above):

```yaml
name: Impact comment
on:
  workflow_run:
    workflows: [Impact]
    types: [completed]

jobs:
  comment:
    if: github.event.workflow_run.event == 'pull_request' && github.event.workflow_run.conclusion == 'success'
    permissions:
      contents: read
      pull-requests: write
    uses: jimyag/ripples-action/.github/workflows/comment.yml@main
```

The reusable workflow finds the open PR matching the completed run's head repository and commit. It analyzes the PR with a read-only token, then uses a separate job with `pull-requests: write` to update one comment. If the PR changes before the comment is posted, the stale result is skipped. This works for PRs from forks and from branches in the base repository. The comment workflow repeats analysis so it does not trust results produced by a workflow the PR author could edit.

If you only need comments, `Impact` can be an existing successful PR workflow; the reusable workflow performs the analysis itself. GitHub may require a maintainer to approve a first-time contributor's fork workflow before the comment workflow can run.

`workflow_run` must be enabled by the repository's Actions policy. The comment workflow must exist on the default branch. For a Go module below the repository root, pass `with: {repo-path: path/to/module}` to the reusable workflow. The analysis job currently fetches PR code without credentials, so this setup targets public repositories. The two jobs use separate GitHub-hosted runners; do not run the analysis job on a shared runner that exposes secrets or internal resources.

For same-repository PRs only, the analysis Action still offers `comment: 'true'` with `github-token` and `pull-requests: write`. Use the separate workflow above when fork PR comments are required. Do not run untrusted PR code with a write token via `pull_request_target`.

The example tracks `main`. Pin a commit SHA or a release tag when you need a fixed action version.
