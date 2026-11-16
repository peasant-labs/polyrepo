# release-intent commands

The tool lives in `peasant-labs/infra` under `tools/release`. Consumers build it
from one pinned 40-hex commit; never run a local fork or a different pin.

## Build it

```sh
git clone https://github.com/peasant-labs/infra /tmp/infra
git -C /tmp/infra checkout <the-pinned-sha>
GOWORK=off go build -C /tmp/infra/tools/release -o /tmp/release-intent ./cmd/release-intent
```

`GOWORK=off` matters when the current repository has a `go.work` that does not
list the tool module; otherwise `go build` refuses with “contained in a module
that is not one of the workspace modules”.

## Exit codes

| Exit | Meaning |
|---|---|
| `0` | The command accepted; `error=` is empty. |
| `1` | A read, usage, or environment fault. The message carries the why/where/when/means/fix parts. No typed code. |
| `2` | A typed rejection. The output includes `error=<code>` and a six-part message. |

## Commands

### `check-config`

```sh
release-intent check-config --config .github/release-intent.yaml
```

`--config` is optional and defaults to the repo's release-intent file. Prints
`ok=true`; a bad config exits 2 with `config-invalid`.

### `check-workflows`

```sh
release-intent check-workflows --policy .github/release-queue.policy.yml --dir .github/workflows
release-intent check-workflows --policy .github/release-queue.policy.yml --dir .github/workflows --print-required
```

`--dir` is required. `--policy` is optional. The full command is the gate;
`--print-required` prints the required contexts and is for comparing the policy
with the queue ruleset. Do not use the printing form as the only check: at the
current tool it prints the contexts without reporting every policy violation.

### `check-title`

The title is read on stdin.

```sh
printf '%s\n' 'feat(graph)[minor]: add a facet' |
  release-intent check-title \
    --base "$BASE_SHA" --head "$HEAD_SHA" \
    --author "$PR_AUTHOR" --head-branch "$PR_HEAD_BRANCH"
```

`--base`, `--head`, `--author`, and `--head-branch` are required. The base
config is authoritative; on the adopting PR, where the base has no config, the
tool reads the config from the head and skips the protected-path comparison.
Prints `error=` on success; exits 2 with a code on rejection.

### `classify`

```sh
release-intent classify --author "$PR_AUTHOR" --head-branch "$PR_HEAD" --rev "$BASE_REV"
```

Prints `kind=ordinary|release|vendor-hash|cut-release`. The classifier reads the
release config's `bot_branches`; no workflow compares a branch literal.

### `group-pr`

```sh
release-intent group-pr --ref "$GITHUB_REF"
```

Prints `pr=<number>` for a merge-group ref, or an empty `pr=`. Used to resolve
the entry PR of a merge-group build without parsing group commits.

### `plan`

```sh
release-intent plan --branch origin/main --mode tag --verdict taggable --floor "$RELEASE_BATCH_FLOOR"
release-intent plan --branch origin/main --mode plan-only
```

`--branch` and `--mode` are required. `--mode` is `plan-only` or `tag`; the
workflow passes the `RELEASE_BATCH_MODE` value, which is empty until tag mode is
turned on. `--verdict` is `taggable`, `rejected`, or omitted. `--floor` is the
recovery commit.

Outputs:

| Field | Meaning |
|---|---|
| `action` | `none`, `open-pr`, `verify`, `tag`, or `close-pr`. |
| `range_base` | The newest final tag on the branch chain. |
| `version_base` | The highest final tag anywhere. |
| `candidate` | The release commit the plan would tag, or empty. |
| `candidate_fresh` | `true`, `false`, or empty when there is no candidate. |
| `level` | `none`, `patch`, `minor`, or `major`. |
| `breaking` | `true` or `false`. |
| `version` | The computed bare version, or empty. |
| `tag` | The computed tag, or empty. |
| `error` | Empty on success; a code on rejection. |

### `release-pr`

```sh
release-intent release-pr --check --branch origin/main
release-intent release-pr --write --branch origin/main
release-intent release-pr --commit --branch origin/main --current origin/automation/release
```

Exactly one of `--write`, `--check`, or `--commit`. `--branch` is required;
`--floor` is optional; `--current` applies to `--write` and `--commit`.

- `--check` compares the working tree with the generated content. A mismatch is
  `release-content-stale` (exit 2); a read error is exit 1.
- `--write` writes the changelog and each version field into the working tree.
  It does not commit or push.
- `--commit` prepares a separate local release commit with the bot author and
  committer and the source commit's timestamp. It requires a clean index and
  worktree, including untracked files, and stages only generated content.
  `push=true` means the checked-out branch now points at the commit; `push=false`
  means the current branch already has fresh, in-scope content. A required push
  with no generated changes, or a version-only result with no changelog change,
  is an error.

All modes print `fresh`, `push`, `version`, and `error`. The workflow sets the
`source` output itself before calling `--commit`.

### `queue-gate`

```sh
release-intent queue-gate --queue queue.json --release-pr "$RELEASE_PR"
```

Reads the raw merge-queue GraphQL response and prints `gate=arm` or `gate=hold`.
Arm only when no releasing PR is ahead of the release PR. On hold, only turn
auto-merge off for an armed release PR that is not queued; a queued release PR
is never dequeued.

### `verify-tag`

```sh
release-intent verify-tag --tag "$TAG" --branch "origin/main"
```

Passes only when the tag is the release config's prefix plus an `X.Y.Z` version
and the named branch reaches the tag's commit. The tag-triggered release and
npm workflows run it before publishing.

## Reading a rejection

A typed rejection carries six parts in one line:

```text
release-intent: <code>: <what> [why: ...; where: ...; when: ...; means: ...; fix: ...]
```

Read the `fix` first. A landed subject that fails is fixed with
`RELEASE_BATCH_FLOOR`; a live PR title is fixed with a retitle; a stale release
PR is fixed by rebuilding, never by hand-editing its content.
