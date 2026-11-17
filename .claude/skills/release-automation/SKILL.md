---
name: release-automation
description: Explain and operate the peasant-labs release mechanism. Covers the release-intent title grammar (`type(scope)[level]: subject`), the computed-version planner, the standing `automation/release` bot PR, the batched native merge queue, the App-authenticated tag, the tag-triggered GitHub Release and package publish, and the generator that owns CHANGELOG.md. Use whenever a task involves releasing a peasant-labs repo, cutting a release by hand, writing or judging a PR title, updating CHANGELOG.md, debugging why no release PR or tag appeared, or reading `release-intent`, `release-batch.yml`, `cut-release.yml`, `RELEASE_BATCH_MODE`, or `verify-tag`.
---

# release-automation

This is the operating guide for how peasant-labs repositories release. The
short version: **titles carry intent, the tool computes every number, one
standing bot PR writes the release content, the merge queue lands it, and the
release job pushes the tag.** Authors never choose a version and never edit the
changelog.

Use the references when you need exact detail:

- `references/title-syntax.md` — the grammar, type classes, levels, breaking
  rules, and every rejection code.
- `references/changelog.md` — how the generated section is built, how
  `[Unreleased]` is handled, and how de-duplication works.
- `references/manual-cut.md` — the forced-release button, the empty-commit PR,
  the plan-only check, and recovery.
- `references/commands.md` — every `release-intent` subcommand, flag, output,
  and exit code.
- `references/repo-wiring.md` — the files, credentials, rulesets, and checks a
  consumer repo needs.

## The model in one page

1. **A PR title is intent.** Write `type(scope)[level]: subject`. A releasing
   title carries a bracket; the bracket is a level (`patch`, `minor`), never a
   number. The title guard checks the live title before the queue and again in
   every merge-group build.
2. **The planner computes the version.** `release-intent plan` reads the
   first-parent history from the newest final tag on the branch chain, parses
   every landed subject, and computes one version from the highest level in the
   pending set. Below 1.0 a breaking change is `![minor]`; `![patch]`,
   `![major]`, and `[major]` are rejected.
3. **One standing release PR.** The bot branch is `automation/release`, opened
   by `app/peasant-labs-releaser`. It carries the changelog section and the
   version field (when the repo has one). It is rebuilt from the branch tip
   whenever the pending set changes. It lands through the queue by auto-merge.
4. **The tag goes on the release PR's landed commit.** The planner marks a
   candidate fresh only when its content matches the generator now. A fresh,
   taggable candidate is tagged; a stale one is never tagged, and the next run
   rebuilds the release PR.
5. **The tag publishes.** The tag-triggered `release.yml` (and, for npm
   packages, `npm-publish.yml`) verifies the tag is a release tag whose commit
   the default branch reaches, then publishes the GitHub Release and package.
6. **The queue batches.** PRs land in groups through the native merge queue.
   The queue arms the release PR only when no releasing PR is ahead of it. A
   queued release PR is never dequeued.
7. **The changelog is bot-owned.** The release PR writes the whole file. An
   author PR that touches it fails `title-guard` with `protected-path`. A tag
   without a matching section fails the release-notes job; the fix is forward,
   never a hand edit of a published version.

## Where the contract lives

Every releasing repo carries the same four pieces:

| File | What it is |
|---|---|
| `.github/release-intent.yaml` | The release config: `tag_prefix`, `automation_author`, `changelog`, `version_files`, `protected_paths`, `surfaces`, `bot_branches`, and `releases`. |
| `.github/release-queue.policy.yml` | The queue contract: required contexts, the release job, and the bot jobs. |
| `.github/workflows/title-guard.yml` | The title and protected-path gate, on every PR event and every merge-group build. |
| `.github/workflows/release-batch.yml` | The serialized `plan` / `verify` / `release` run that keeps the release PR current and tags its landed commit. |
| `.github/workflows/cut-release.yml` | The maintainer's forced-release button. |
| `.github/workflows/release.yml` | The tag-triggered GitHub Release. npm repos also carry `npm-publish.yml`. |

The checks build `release-intent` from the same pinned `peasant-labs/infra`
commit in every workflow. Read the live values rather than assuming them:

```sh
rg -n 'peasant-labs/infra|ref:|release-intent' .github/workflows
cat .github/release-intent.yaml
cat .github/release-queue.policy.yml
```

## The title, briefly

```text
type(scope)[level]: subject
type(scope)! [level]: subject     # the ! declares a break
```

- `type` is one of `feat`, `fix`, `release`, `refactor`, `perf`, `build`,
  `revert`, `docs`, `test`, `ci`, `chore`, `style`.
- `feat`, `fix`, and `release` always release and always carry a bracket.
- `refactor`, `perf`, `build`, and `revert` release only with a bracket.
- `docs`, `test`, `ci`, `chore`, and `style` never carry a bracket.
- Below 1.0 a break is `![minor]`. From 1.0 it is `![major]`.
- A repo with `releases: false` rejects any bracket or `!`; `feat(scope): x`
  is accepted.

The squash commit adds ` (#123)`; the parser strips it and the changelog line
keeps it. Full rules and examples: `references/title-syntax.md`.

## What happens after a merge

The planner's two bases matter:

- **range base**: the newest final release tag on the branch's first-parent
  chain. The pending set starts after it.
- **version base**: the highest final release tag anywhere. Version arithmetic
  starts from it, so an off-chain higher tag still wins.

The planner also reads the **epoch** (the commit that added the release config;
subjects before it are never parsed) and the optional **floor** (a recovery
commit that drops a bad subject and everything before it). It returns exactly
one action:

| Action | Meaning |
|---|---|
| `none` | Tag mode is off. Print the plan and write nothing. |
| `open-pr` | There is a pending set; build or rebuild the release PR. |
| `verify` | A fresh candidate exists and no verdict was given; run the repo's pre-tag steps, then plan again with the verdict. |
| `tag` | A fresh candidate exists and the verdict is `taggable`; push the tag. |
| `close-pr` | Nothing is pending; close an open release PR. |

`release-batch.yml` has three jobs. `plan` holds no App credential: it builds
the tool, plans, prepares the tag and the release commit, reads the queue, and
hands over git bundles. `verify` holds no credential either: on a separate
runner it recomputes the plan, binds the release source to the current default
branch tip, and verifies the bundles. `release` holds the App token and runs
only pinned actions, bundle fetches, and one `git push` or `gh` command per
step. The write steps are gated on the one action the planner printed.

## How the changelog updates

Only the release PR writes `CHANGELOG.md`. The generator places a new section
in the heading style the file already uses, renders one line per pending
subject (`- subject (#PR)`, plus ` (BREAKING)` when the title declares one),
and keeps an existing `[Unreleased]` block's entries above the generated lines
under the new heading. A repeated request to cut the same release collapses to
one line; the newest request names it and the strongest level wins.

The release PR is compared with the generator (`release-pr --check`). If the
branch tip moved, the content is stale, the PR fails `release-content-stale`,
and the release job rebuilds it. A tag without a matching section fails the
tag-triggered notes job. Never hand-edit the file. Full rules and examples:
`references/changelog.md`.

## Homebrew cask

Peasant's cask publishes from `peasant-labs/homebrew-tap`, not from the release
workflow. The tap renders `templates/peasant.rb.tmpl` from the latest final
release's public `checksums.txt` on a fifteen-minute schedule, audits the result
on macOS, and pushes with its own workflow token, so peasant holds no tap
credential. Release candidates never reach the tap.

The final-tag `macos-cask-smoke` waits up to sixteen minutes for the tap to
carry the tagged version before installing. A tap that never catches up still
fails the smoke; it is not weakened to install an older package. The tap is a
generated-artifact repository outside the merge queue: its publisher pushes only
its own `main`, and the cask file is never edited by hand.

## Cutting a release by hand

Use this when there is nothing pending but a release is still wanted, or to
recover a release window. The preferred path is the `cut-release.yml` workflow
dispatch with `patch` or `minor`. It creates one empty commit titled
`release[level]: cut a release` on `automation/cut-release`, opens the cut PR
with auto-merge, and the release job builds the release PR from the landed
commit.

The alternative is a PR whose only commit is empty and whose title is
`release[level]: cut a release`. A cut PR that changes any path fails
`release-content-scope`.

Tag mode must be on (`RELEASE_BATCH_MODE=tag`). Before turning it on for a new
repo, run the release batch with the variable unset, inspect the printed plan,
and read back that no branch, PR, or tag was written. Full procedure and
recovery: `references/manual-cut.md`.

## Operating checks

```sh
release-intent check-config --config .github/release-intent.yaml
release-intent check-workflows --policy .github/release-queue.policy.yml --dir .github/workflows
release-intent plan --branch origin/main --mode tag --verdict taggable
release-intent release-pr --check --branch origin/main
release-intent verify-tag --tag vX.Y.Z --branch origin/main
```

Use `--print-required` only to compare the policy's contexts with the ruleset;
it is not a substitute for the full `check-workflows` run. The full command is
the gate. Every command's flags and output fields are in
`references/commands.md`.

## Failure and recovery

- **Stale candidate**: `plan` returns `open-pr`; the release job rebuilds the
  release PR. Never tag a stale commit.
- **No tag**: read the `plan` output. `none` means tag mode is off;
  `close-pr` means nothing is pending; a rejection carries its code.
- **A landed subject the parser cannot read**: set `RELEASE_BATCH_FLOOR` to the
  bad commit and leave it set. The floor drops that subject and everything
  before it; the next plan starts after it.
- **Failed publish after the tag**: the tag burns its number. Fix forward; never
  move or delete a published tag.
- **A release PR that left the queue**: the next schedule or dispatch re-arms
  it. A queued release PR is never dequeued.
- **Two forced cuts in one window**: avoid it. The tool folds identical cut
  requests and keeps the strongest level, but the released section is
  immutable, so the duplicate cannot be edited out afterward.

## Hard rules

- Never write a version, a changelog entry, or a spec number in a PR title.
- Never hand-edit `CHANGELOG.md` or a protected version field; the release PR
  owns them.
- Never create a release tag by hand and never move or delete a release tag.
- Never push the default branch outside the merge queue.
- Never let a general build step run in a job that holds a write credential;
  the release tool's policy exists to keep that boundary.
