---
name: issue-handler
description: Own one peasant-labs GitHub issue through repository worktrees, implementation, repository gates, PR review agents, CI, merge, default-branch sync, and cleanup. Use when asked to handle, fix, close, or ship an issue in a peasant-labs repository.
---

# Issue handler (peasant-labs)

Own one issue through merge. Shipping means research, worktree, implementation, tests, validation, commit, push, PR, independent review, CI, merge, local default-branch sync, and cleanup.

All implementation edits happen in a feature worktree inside the target repository host. Never edit a repository's host checkout or default-branch worktree for issue implementation.

## Preconditions

- The issue number or URL and target GitHub repository are known.
- `gh auth status` succeeds and the authenticated user has the required write access.
- The target repository exists in the polyrepo workspace and has a usable default-branch worktree.
- No open PR already handles the issue. If one exists and you did not create it, attach to it only with user approval. Do not create a duplicate.
- A dirty host or default-branch worktree is not a reason to clean, stash, reset, or overwrite user work.

Stop and ask for missing permissions, an unclear target repository, contradictory acceptance criteria, a foreign worktree collision, or a product decision that the issue does not settle.

## Resolve the repository first

Never rely on the current directory or a bare `gh issue view N`. Issue numbers overlap between repositories, and peasant and village have archive remotes.

| Product repository | GitHub repository | Local host | Default base | Live fetch/push remote |
|---|---|---|---|---|
| Peasant | `peasant-labs/peasant` | `peasant/` | `develop` | `canonical` |
| Village | `peasant-labs/village` | `village/` | `develop` | `canonical` |
| Schema | `peasant-labs/schema` | `schema/` | `develop` | `origin` |
| Fairtrade | `peasant-labs/fairtrade-design-system` | `fairtrade-design-system/` | `main` | `origin` |

For another active workspace repository, inspect its own `AGENTS.md`, remote URLs, remote HEAD, and default worktree before acting. Do not add runtime work to archived `transcript-browser`; its runtime ownership moved to Fairtrade.

Set explicit values and use them for every command:

```sh
GH_REPO="peasant-labs/<repo>"
REPO_HOST="/home/minttea/dev/peasant-labs/<repo-host>"
BASE="develop" # or main
LIVE_REMOTE="canonical" # peasant/village; origin for schema/fairtrade
ISSUE="<number>"
```

Use `gh ... -R "$GH_REPO"` for every issue, PR, comment, review, run, and merge operation. For Peasant and Village, never use the archive `origin` as the live GitHub target or push destination.

## Workflow

1. **Orient** - Read the issue and all comments with `gh issue view "$ISSUE" -R "$GH_REPO"`. Read root `AGENTS.md`, then the target worktree's `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, testing guide, and the architecture or invariant documents named by those files.
2. **Research** - Map acceptance criteria to production paths, callers, tests, fixtures, generated outputs, and consumers. Check related issues and PRs. State observable acceptance bullets. Stop and ask if behavior remains ambiguous.
3. **Classify** - Select risk tier A, B, or C. Identify contract, release, migration, security, and visual review requirements before editing.
4. **Worktree** - Fetch the live base, create or resume the issue branch, and verify the worktree path and branch.
5. **Implement** - Make the smallest correct change. Preserve existing user-facing behavior outside the issue. Use production paths and real dependency wiring.
6. **Test** - Add or update tests for observable behavior. Put combinatorial and table-driven cases in repository fixture files, not inline case tables.
7. **Validate** - Run the target repository's full required gate and all focused gates required by the changed surface. Never weaken or remove tests to make a gate pass.
8. **Visual proof** - For interface changes, capture the mounted production path in both themes from the exact branch, inspect it, verify build provenance, and upload durable screenshots to the PR.
9. **Sync base** - If the live base moved or the branch was open for about one hour, fetch and merge the live base into the feature branch. Regenerate generated artifacts instead of hand-merging them. Re-run the gate.
10. **Ship** - Inspect status, diff, and recent history. Stage intended files only. Commit with `git agent-commit`, push to the live remote, and open a focused PR against the correct base.
11. **Review loop** - Run the required independent review wave on the current PR head. Post findings to the PR, fix blockers, and re-review every material new head.
12. **CI** - Watch all checks on the reviewed head. Fix branch-caused failures, re-run local gates, push, and repeat review when merge-bound files changed.
13. **Merge** - Merge only when the current head meets all review, CI, visual, and repository gates.
14. **Cleanup** - Sync the local default-branch worktree immediately, remove only the worktree and branch you created, delete its live remote branch if it remains, and leave the current directory outside the deleted worktree.

## Risk tiers

The target repository's instructions are the source of truth. Tiers add review and focused validation; they do not replace repository gates.

| Tier | Use when | Local and review bar |
|---|---|---|
| A | Documentation, skills, issue templates, or comments only | Relevant format/link checks; one reviewer optional unless process behavior changes |
| B | Normal code or test behavior | Full repository gate, focused tests, one three-axis review wave with zero blockers on current HEAD |
| C | Wire/API contract, auth, permissions, privacy, redaction, migrations, governance, release workflow, concurrency, storage, or cross-repo behavior | Tier B plus focused integration/security/contract gates and at least one clean three-axis review wave on current HEAD |

Important and minor review findings do not block merge when repository policy permits. Record them as approved follow-up issues. Never hide, omit, or silently downgrade a finding.

## Cross-repository boundaries

- A serialized type, OpenAPI surface, externally observable route, capability token, status behavior, or shared license change starts in `peasant-labs/schema`.
- Land the schema PR and publish the required module tag before consumer re-pin PRs merge. Agents may prepare coordinated consumer branches, but must not merge a consumer against an unpublished contract.
- Shared transcript rendering, graph behavior, design tokens, and canonical transcript components belong in Fairtrade. Consumers adapt and compose; they do not fork the component.
- Redaction rules and canonical redaction fixtures belong in `peasant-labs/redact`. Peasant keeps mounted integration coverage when it re-pins.
- A cross-repo issue uses the primary issue's semantic branch name in every participating repository. Each repository gets its own worktree, commit, PR, gate, and review record.
- If the issue does not authorize required cross-repo work, stop and ask before expanding scope.

## Worktree setup

Use the repository host as the worktree owner. Do not create worktrees under the workspace root or inside a default-branch worktree.

```sh
BRANCH="<primary-repo>-<issue>--<type>--<short-name>"
WT="$REPO_HOST/$BRANCH"

git -C "$REPO_HOST" fetch "$LIVE_REMOTE" "$BASE"
git -C "$REPO_HOST" worktree list

# Resume only if this exact worktree and branch are yours.
git -C "$REPO_HOST" worktree add -b "$BRANCH" "$WT" "$LIVE_REMOTE/$BASE"
```

The branch format is `<primary-repo>-<issue>--<semantic-commit>--<description>`, for example `peasant-224--feat--push-project-labels`.

Before every edit session, run these commands with the tool working directory set to `$WT`:

```sh
pwd
git branch --show-current
git status --short
```

`pwd` must be `$WT` and the branch must be `$BRANCH`. Stop on a foreign worktree or unexpected changes that conflict with the issue. Do not delete another agent's worktree.

## Repository gates

Read the current repository files before selecting commands. At minimum:

| Repository | Baseline gate | Additional gates when relevant |
|---|---|---|
| Peasant | `make check` and `make build` | `ast-grep scan --config sgconfig.yml .` for Go type/literal changes; `make e2e` for Village integration; generated CLI docs; TUI visual-review skill; mounted web visual harness |
| Village | From `backend/`: `go build ./...`, `go test -race ./...`, `gofmt -l .`, `go vet ./...`; from `frontend/`: `pnpm lint`, `pnpm test`, `pnpm build` when frontend changes | `make backend-encrypted-test` or tagged integration tests for SQL, transactions, triggers, encryption, or object storage; sqlc regeneration; mounted visual harness |
| Schema | `make check` | `make gates BASE_REF=<live-remote>/<base>` for contract changes; `make schema` before freshness checks when source changes; package audit/smoke are included by the full gate |
| Fairtrade | `pnpm build`, `pnpm build:lib`, `node scripts/sbsmoke.mjs` | Changed-component stories, both-theme screenshots, package/tarball smoke, and relevant visual or mutation gates |

Focused Go tests always use `-race`. Integration behavior that depends on PostgreSQL, S3-compatible storage, migrations, triggers, or transaction GUCs must use real services as required by Village's `TESTING.md`.

Generated files are never hand-edited or hand-merged. Change the source and run the pinned generator. Confirm regeneration leaves no unexplained diff.

## Interface changes

Every interface-changing PR requires mounted screenshots from the exact PR branch in both themes. A Storybook-only image is not enough when a consumer path changed.

Before trusting a capture:

- Confirm the server serves the worktree build, not a stale server or another Fairtrade checkout.
- Check the built artifact for a marker introduced by the branch.
- Capture the full mounted shell and changed body at desktop and mobile sizes when both can change.
- Run computed-style probes for token, font, layout, and theme claims.
- Compare consumer surfaces to the live Fairtrade in-use demo when design-system fidelity is involved.
- Inspect every image and the standing prior-finding checklist before upload.
- Keep local proof PNGs untracked. Put durable GitHub-hosted images in the PR body or a linked PR comment.

## Commit and push

Inspect before committing:

```sh
git status --short
git diff
git log --oneline -10
```

Stage intended paths only. Do not stage unrelated user or agent changes.

```sh
git add <intended-paths>
git agent-commit -m "type(scope): concise summary"
git push -u "$LIVE_REMOTE" HEAD
```

Use the repository's conventional commit style. Do not include internal Beads IDs, slice names, wave names, phase names, or other task taxonomy in shipped code, docs, or commit messages. Do not amend, force-push, skip hooks, install hooks, or push secrets.

## Open the PR

```sh
gh pr create -R "$GH_REPO" --base "$BASE" --head "$BRANCH" \
  --title "type(scope): concise summary" --body-file <pr-body-file>
```

The PR body must contain:

```md
## Summary
- user-visible outcome
- important implementation boundary

## Issue
Fixes #<N>

## Risk
Tier A | B | C, with reason

## Verification
- exact command and result
- exact command and result

## Visual review
- mounted screenshots and build provenance, or `not applicable` with reason

## Cross-repo impact
- contract, release, consumer, or deployment order, or `none`
```

Call out migrations, compatibility changes, manual deployment steps, skipped checks, and why any check was not available. Keep the body concise and factual.

## Independent review loop

Tier B and C changes require three fresh independent reviewers in one parallel wave:

- A: correctness and end-user behavior
- B: test quality, production-path coverage, fixtures, and non-vacuity
- C: simplicity, maintainability, boundaries, and missed reuse

Each reviewer prompt must include the exact GitHub repository, PR number or URL, base branch, current `headRefOid`, issue acceptance criteria, repository instructions, and the standing prior-finding checklist. Require the reviewer to:

- Run `gh pr diff <PR> -R <repo>` or inspect the full patch.
- Read surrounding callers, tests, fixtures, generated sources, and mounted wiring.
- Report ranked findings with `path:line`, severity `BLOCKER`, `IMPORTANT`, or `MINOR`, a concrete failure scenario, and the reviewed SHA.
- Check shipped-artifact hygiene and fixture rules.
- Avoid impact-free style comments.
- Make no edits and return paste-ready findings.

Post every review result to the PR. Automated reviews use `COMMENT`, never self-approval or self-request-changes. Post findings verbatim; do not omit or downgrade them. If you dispute a blocker, post the dispute and stop for user direction.

A clean pass is also recorded on the PR and cites the exact reviewed SHA:

```md
## Review pass N (head `<sha>`) - clean
Axes A, B, and C: 0 blockers. Important and minor findings are resolved or linked to approved follow-up issues.
```

After any push that changes code, tests, fixtures, skills, workflows, generated artifacts, or user-visible docs, run a new review wave on the new head. A clean review of an older SHA does not count. Stop and ask if five waves do not reach zero blockers.

## Address findings

1. Pull all human and automated PR comments and review threads.
2. Fix every blocker. Fix important and minor findings when safe and in scope; otherwise create or link an approved follow-up issue and explain the deferral on the PR.
3. Add or adjust tests when behavior changes.
4. Re-run the full repository gate and focused checks.
5. Commit with `git agent-commit`, push a new commit, and reply with the commit SHA and result.
6. Run a fresh three-axis review wave on the new `headRefOid`.

## CI and merge gate

Watch CI with explicit repository identity:

```sh
gh pr checks <PR> -R "$GH_REPO" --watch
gh pr view <PR> -R "$GH_REPO" --json state,mergeable,mergeStateStatus,statusCheckRollup,reviewDecision,isDraft,headRefOid
```

Rerun an identified infrastructure-only failure at most twice. Fix branch-caused failures in the worktree. Stop after one bounded diagnosis when ownership is unclear.

Merge only when all conditions are true:

- The reviewed SHA equals the current PR head.
- The current-head review wave has zero blockers.
- Important and minor findings are fixed or linked to approved follow-up issues.
- All actionable human comments are addressed.
- `reviewDecision` is not `CHANGES_REQUESTED`.
- Required CI checks are green on the current head.
- Local repository and focused gates passed on that commit.
- Required mounted screenshots are durable and inspected.
- Contract-first and release ordering is complete.
- The PR is open, not draft, and mergeable.

Use the merge method required by the target repository. Do not guess or override branch policy. Peasant, Village, and Fairtrade normally land focused PRs as one squashed change. Schema follows its documented squash and merge-commit ceremony. Never push release tags; release tags are minted by repository automation after a maintainer merges an approved release PR.

## Cleanup after merge

Verify the PR state and merge commit from GitHub, then sync the local default branch immediately:

```sh
gh pr view <PR> -R "$GH_REPO" --json state,mergeCommit
git -C "$REPO_HOST/$BASE" pull --ff-only "$LIVE_REMOTE" "$BASE"
git -C "$REPO_HOST" worktree remove "$WT"
git -C "$REPO_HOST" branch -d "$BRANCH"
git -C "$REPO_HOST" push "$LIVE_REMOTE" --delete "$BRANCH"
git -C "$REPO_HOST" worktree prune
```

Delete only the branch and worktree you created. If remote branch deletion is already complete, report that result and continue. Never leave the tool working directory inside a removed worktree.

## Hard rules

1. Resolve the GitHub repository, live remote, base branch, and worktree host before any write.
2. Never implement an issue in a host or default-branch checkout.
3. Never use Peasant or Village's archive `origin` for live issue, PR, push, or merge work.
4. Never merge a consumer before its required schema contract is published and pinned.
5. Never hand-edit generated files or place combinatorial test tables inline.
6. Never install or modify Git hooks without explicit user permission.
7. Never merge with blockers, failing checks, stale review SHA, missing visual evidence, or incomplete local gates.
8. Never omit or downgrade reviewer findings. Disputes require user direction.
9. Never force-push, use destructive reset, skip hooks, expose sensitive data, or weaken tests for green.
10. Always sync the local default-branch worktree and clean up the feature worktree after merge.

## Stop and ask

- Authentication, live-repository write access, or branch protection prevents the workflow.
- The issue has an open PR owned by someone else.
- Acceptance criteria conflict or require a product choice.
- Required cross-repo work is not authorized by the issue.
- A foreign worktree or unexpected conflicting changes occupy the branch.
- A merge conflict cannot be resolved from repository rules and generated sources.
- CI remains red after two infrastructure reruns or ownership is ambiguous.
- A reviewer blocker is disputed or five review waves do not clear blockers.
- A release tag, secret, security policy, or GitHub setting would need a manual change not authorized by the user.

## What this skill is not

- Not an implementation path for archived transcript-browser runtime work.
- Not permission to implement unrelated roadmap items or issue-epic siblings.
- Not a substitute for repository-local TUI, visual, release, migration, or test instructions.
- Not a reason to maximize parallelism when cross-repo ordering or file conflicts require sequence.
