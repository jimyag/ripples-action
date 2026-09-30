# ripples-action

Run [Ripples](https://github.com/jimyag/ripples) on a Go pull request and expose its affected packages as GitHub Actions outputs. A separate trusted workflow can comment on PRs from forks.

For CLI installation, analysis semantics, `-tests`, and generated code, see the [Ripples usage guide](https://github.com/jimyag/ripples/blob/main/docs/usage.en.md).

## Affected package outputs

```yaml
name: Impact
on: pull_request

permissions:
  contents: read

jobs:
  impact:
    runs-on: ubuntu-latest
    outputs:
      mains: ${{ steps.impact.outputs.mains }}
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: actions/setup-go@v7
        with:
          go-version-file: go.mod
      - id: impact
        uses: jimyag/ripples-action@v0.1.0
        with:
          base-sha: ${{ github.event.pull_request.base.sha }}
          head-sha: ${{ github.event.pull_request.head.sha }}
          ripples-version: v0.3.1
      - name: Use affected packages
        env:
          PACKAGES: ${{ steps.impact.outputs.packages }}
          MAINS: ${{ steps.impact.outputs.mains }}
        run: |
          echo "$PACKAGES"
          echo "$MAINS"

  build:
    needs: impact
    if: needs.impact.outputs.mains != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        target: ${{ fromJSON(needs.impact.outputs.mains) }}
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-go@v7
        with:
          go-version-file: go.mod
      - name: Build affected main
        env:
          TARGET: ${{ matrix.target }}
        run: go build -o "$RUNNER_TEMP/service" "./${TARGET%.*}"
```

The action sets three outputs:

| Output | Value |
| --- | --- |
| `packages` | JSON array of affected packages, for example `["cmd/server.main","payment.payment"]` |
| `mains` | JSON array of affected `main` packages, for example `["cmd/server.main"]` |
| `has-changes` | `true` or `false`; counts non-deleted packages |

Export step outputs as job outputs, then use `fromJSON(needs.impact.outputs.mains)` in a downstream matrix. A matrix cannot reference the producing job's `steps` context. The job-level `if` skips an empty matrix. See [GitHub's context availability reference](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#context-availability).

Both arrays contain `<module-relative-path>.<package-name>`, not Go import paths or service names. A module-root main package is `..main`; remove the final `.main` to obtain the directory. Deleted packages are omitted. A deletion with no affected surviving packages produces `[]` and `has-changes=false`. Analysis failures fail the action; they do not produce empty outputs. Map the output to your own build jobs or labels; the Action does not create labels.

## Inputs and requirements

| Input | Default | Meaning |
| --- | --- | --- |
| `base-sha` | Required | Old commit or ref to compare; must resolve in the checkout |
| `head-sha` | Required | New commit or ref to compare; must resolve in the checkout |
| `repo-path` | `.` | Go module directory inside the checkout |
| `ripples-version` | `v0.3.1` | Stable Release tag in `vX.Y.Z` form; `latest` and prerelease tags are not accepted |
| `comment` | `'false'` | Set to `'true'` for direct same-repository PR comments |
| `github-token` | Empty | Use `${{ github.token }}` with `pull-requests: write` when direct comments are enabled |

The caller must check out both commits (`fetch-depth: 0`) and install Go with `actions/setup-go`. Linux amd64 and arm64 runners are supported; `bash`, `git`, `curl`, `jq`, and `sha256sum` must be available. Comments additionally require `gh`. GitHub-hosted Ubuntu runners provide these tools. The Action downloads a release binary and verifies it against that release's `checksums.txt`.

The default is v0.3.1. Starting with that release, Ripples sets `GOTOOLCHAIN` to the Go version used to build its binary; the installed `go` command must be Go 1.21 or later, and downloads the selected toolchain if missing. The selected version must support both revisions' `go.mod` requirements. Setting `ripples-version` affects only that Action invocation.

For a nested module, set `repo-path` and update `setup-go`'s `go-version-file`; downstream commands must also run in that module. The Action analyzes one module per invocation. It does not expose Ripples's `-tests` or `-prepare` options: test-only changes are omitted, and required generated code must already be committed. Use the [CLI workflow](https://github.com/jimyag/ripples/blob/main/docs/ci.en.md#call-the-cli-directly) when those options are needed. Build configuration such as `GOOS`, `GOARCH`, and `GOFLAGS`, and Ripples cache variables, can be supplied through step `env`.

## Comments on fork PRs

Save the first workflow as `.github/workflows/impact.yml` and this second workflow as `.github/workflows/impact-comment.yml` in the base repository. Its `workflows` value must match the first workflow's `name` (`Impact` above), not its filename:

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
    uses: jimyag/ripples-action/.github/workflows/comment.yml@v0.1.0
```

The reusable workflow finds the open PR matching the completed run's head repository and commit. It analyzes the PR with a read-only token, then uses a separate job with `pull-requests: write` to update one comment marked `<!-- ripples-action -->`. An empty result updates the comment to `None.`. If no open PR matches, or the head SHA changes before publishing, the result is skipped. If multiple open PRs match the same head repository and SHA, resolution fails rather than picking one. The comment workflow repeats analysis so it does not trust results produced by a workflow the PR author could edit.

If you only need comments, `Impact` can be an existing successful PR workflow; the reusable workflow performs the analysis itself. GitHub may require a maintainer to approve a first-time contributor's fork workflow before the comment workflow can run.

Both workflows should be merged into the default branch before testing. The repository's Actions policy must allow the Actions and reusable workflow; the caller must grant the permissions shown above because a reusable workflow cannot increase them. Fork authors need no additional secrets. For a Go module below the repository root, pass `with: {repo-path: path/to/module}` to the reusable workflow. Public and private repositories are supported: the fetch command uses the job's read-only token through a temporary credential helper, without storing it in the repository. The two jobs use separate GitHub-hosted runners; do not run the analysis job on a shared runner that exposes secrets or internal resources. See [GitHub's `workflow_run` requirements](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run).

The reusable workflow accepts `repo-path` (default `.`) and `ripples-version` (default `v0.3.1`) and exposes no caller outputs. To select another release for comments, add `with: {ripples-version: vX.Y.Z}` to the calling job as well; the first workflow's inputs are not inherited. Neither entry point exposes `-tests` or `-prepare`.

For same-repository PRs only, the analysis Action still offers `comment: 'true'` with `github-token: ${{ github.token }}` and `pull-requests: write`. Use the separate workflow above when fork PR comments are required. Direct comments need a `pull_request` event to obtain the PR number; they do not work on ordinary `push` events. Comment reuse matches `github-actions[bot]`, so a personal access token can create duplicate comments instead of updating them. Do not run untrusted PR code with a write token via `pull_request_target`.

## Version pinning and validation

The examples use Action release `v0.1.0`. Pin a commit SHA to freeze the root composite Action's scripts; `ripples-version` separately chooses the Ripples binary. The reusable comment workflow pins its internal Ripples Actions to full commit SHAs, so pinning the outer workflow also fixes those script versions. Third-party Actions such as checkout and setup-go still use major-version tags; pin those separately if your policy requires every dependency to be immutable.

Same-repository comments were verified in the private [demo PR #3](https://github.com/jimmicro/demo-repository/pull/3): changing two independent declarations reported `cmd/alpha.main` and `cmd/beta.main`, omitted the independent command, and updated the same bot comment. A real external fork PR has not been verified because that test repository disables forks. The fork path is implemented, but its end-to-end verification remains outstanding.
