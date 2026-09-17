---
name: issue-orchestrator
description: Drive approved peasant-labs issues across multiple repositories to merge through dependency-aware worktrees and issue-handler agents. Use when asked to orchestrate issues, farm a backlog, or coordinate multiple issue-to-merge lanes.
---

# Issue orchestrator (peasant-labs)

Coordinate many approved GitHub issues across the polyrepo. Do not implement production code in repository hosts or default-branch worktrees. Each shippable issue is owned by an `issue-handler` in one or more isolated feature worktrees.

## When to use

- The user asks to orchestrate, farm, or drain approved GitHub issues.
- A cross-repo epic has multiple repository-owned children.
- Several independent issues can progress in parallel without violating contract or file boundaries.

Use `issue-handler` directly for one issue. Use `epic-composer` before this skill when findings still need issue design and user approval.

## Repository identity

Never use bare `gh` commands from the workspace root. Every query includes `-R owner/repo`.

| Repository | Base | Live remote | Local default worktree |
|---|---|---|---|
| `peasant-labs/peasant` | `develop` | `canonical` | `peasant/develop` |
| `peasant-labs/village` | `develop` | `canonical` | `village/develop` |
| `peasant-labs/schema` | `develop` | `origin` | `schema/develop` |
| `peasant-labs/fairtrade-design-system` | `main` | `origin` | `fairtrade-design-system/main` |

Inspect active repositories not listed here before scheduling them. Do not schedule new runtime work in archived `transcript-browser`.

## Source of truth

For each repository, refresh:

```sh
gh issue list -R <owner/repo> --state open --limit 100
gh pr list -R <owner/repo> --state open
gh issue view <N> -R <owner/repo>
git -C <repo-host> worktree list
git -C <repo-host> fetch <live-remote> <base>
```

Read issue sections such as `Blocked by / Blocks`, `Children`, `Related`, and acceptance criteria. GitHub issue references and current repository state are authoritative.

## Dependency rules

Build a directed graph from explicit issue evidence:

- `A blocked by B` means B must merge or close first.
- A schema contract PR and required tag must complete before consumer re-pin PRs merge.
- Fairtrade source changes land and publish before consumer adoption PRs re-pin when the issue requires a package release.
- Database migration and backend API work must precede frontend work only when the frontend cannot test against the old contract. Independent mounted UI work may proceed on a coordinated branch but cannot merge early if it depends on unpublished behavior.
- An epic is not a shippable lane. Dispatch its approved child issues.

Do not infer a hard dependency from a `Related` link. Stop and ask when issue bodies disagree.

## Conflict rules

Do not run issues in parallel when they modify the same semantic production path, generated source, migration sequence, release ceremony, or canonical component. File overlap alone is not always a conflict, but shared behavior ownership is.

Common serialization points include:

- Schema version stamps, generated specifications, and release PRs.
- Peasant store migrations, ingest pipeline wiring, CLI command fixtures, and generated CLI docs.
- Village migration numbers, sqlc source and generated output, governance triggers, and shared frontend route shells.
- Fairtrade tokens, `src/index.css`, shared transcript components, graph registry, and package releases.
- Cross-repo package publication followed by consumer re-pins.

Use one semantic branch name across repositories for one cross-repo issue, but one isolated worktree per repository. The issue handler owns each repository's commit, PR, tests, review, merge, and cleanup.

## Ready set

An issue is ready only when all conditions are true:

- State is open and scope is approved.
- Every explicit blocker required before implementation is closed, or the issue explicitly permits coordinated pre-merge development.
- Every blocker required before merge has a known landing order.
- No open PR already implements the issue.
- No active lane owns a conflicting semantic path.
- Required repository permissions and local worktree host are available.
- The issue has enough acceptance detail for an issue handler to proceed without inventing product behavior.

Priority order:

1. User-selected issue or release-critical blocker.
2. Security, privacy, data-loss, broken production behavior, and failing baseline work.
3. Lowest-level dependency that unlocks the most approved work.
4. Repository priority in issue titles, `P1` before `P2` before `P3`.
5. Lowest issue number as a stable tie-breaker.

The default parallelism cap is four lanes. Lower it when gates are resource-heavy, cross-repo releases serialize work, or semantic conflicts reduce safe concurrency.

## Dispatch

For each ready issue:

1. Spawn an issue-handler agent with the exact `owner/repo`, issue number or URL, base branch, live remote, known dependencies, acceptance criteria, and conflicting paths.
2. Require the handler to read root and repository-local instructions before creating its worktree.
3. Track `repository issue -> worktree -> branch -> PR -> head SHA -> review -> CI -> merge`.
4. For cross-repo work, record the ordered PR chain and package/tag gate. Never merge out of order.

When the user requests an epic swarm, use the workspace `aura-swarm start --epic <id>` workflow and its worktree-based agents. Do not launch long-running supervisor or worker Task subagents for an epic. For a small approved set, issue-handler agents can run in parallel as separate lanes.

## Review coordination

Each code-changing PR must complete the issue-handler's three-axis review wave on its current head SHA. Batch completed work for a coordinated review wave when several related lanes finish together, but preserve findings and verdicts per PR.

Reviewers are fresh for each wave. Continuity lives in issue/PR records and the standing prior-finding checklist. Review agents must post or return paste-ready findings; the handler posts every finding verbatim to the correct PR.

Zero blockers permits merge when all other gates pass. Important and minor findings become approved follow-up issues instead of silently disappearing. Do not create a duplicate follow-up when an existing issue already owns the finding.

## Orchestrator loop

```text
loop:
  1. Refresh issues, PRs, checks, worktrees, package tags, and live bases.
  2. Rebuild the dependency and conflict graphs from current evidence.
  3. Fill safe slots with the highest-priority ready issues.
  4. Ensure each in-flight lane advances through implementation, review, CI, and merge.
  5. On package or contract publication, unlock consumer re-pin lanes.
  6. After merge, verify default-branch sync and worktree cleanup.
  7. On a blocker, record it on the issue or PR and free the lane if no useful work remains.
  8. Exit when the approved set is merged, the user stops, or only blocked work remains.
```

Do not poll background agents with sleeps. Continue independent work and use completion notifications.

## CI and stalls

| State | Action |
|---|---|
| Branch-caused CI failure | Return lane to its handler for fix, full local gate, push, and fresh review |
| Infrastructure-only failure | Rerun failed jobs at most twice, then stop and ask |
| Base moved | Handler merges the live base into its worktree and reruns gates |
| Generated conflict | Merge canonical source and regenerate; never hand-merge output |
| Product ambiguity | Record exact question and stop that lane |
| Five review waves with blockers | Stop and ask; do not merge |
| Contract package not published | Keep consumers open or prepared, but do not merge re-pins |

## Reporting

Lead with repository-qualified status:

```text
Ready: peasant#N, fairtrade-design-system#M
In flight: village#N -> PR <url> (review | CI | blocked)
Waiting: peasant#M blocked by schema#N tag
Merged: schema#N -> <merge SHA>; local develop synced
Next: village#M because its contract dependency is now published
```

Do not claim green, reviewed, merged, published, or synced without checking GitHub and the local default worktree.

## Cleanup and completion

After every merge, require the handler to:

- Verify GitHub merge state and merge commit.
- Pull the live base into the repository's local default worktree immediately.
- Remove only its feature worktree.
- Delete only its local and live remote feature branch.
- Prune worktree metadata.
- Leave the current directory outside the deleted worktree.

Before reporting the approved set complete, verify every issue is closed, every PR is merged, required packages/tags exist, consumer pins use published versions, required screenshots are durable, CI is green, and no handler worktree remains.

## Hard rules

1. Always qualify issue and PR numbers with their repository.
2. Never use Peasant or Village's archive `origin` for live work.
3. Never implement production code in a host or default-branch checkout.
4. Never parallelize semantic conflicts or violate contract/package landing order.
5. Never duplicate an existing PR.
6. Never merge over blockers, stale reviews, failing checks, missing visual evidence, or incomplete repository gates.
7. Never install Git hooks, force-push, hand-merge generated files, or expose sensitive data.
8. Never turn unapproved review findings into silent scope changes. Use approved follow-up issues.
9. Never schedule archived transcript-browser runtime work.
10. Always verify local default-branch sync and feature-worktree cleanup after merge.

## Stop and ask

- Authentication, permissions, or live remote identity is unclear.
- Issue dependencies conflict or a cross-repo owner is missing.
- Two lanes need the same semantic production path and order is not clear.
- A manual release tag, repository setting, secret, or production operation is required without explicit authorization.
- CI is still blocked after bounded infrastructure retries.
- A review blocker is disputed or persists after five waves.
- Only blocked issues remain or the requested issue set is not approved.

## What this skill is not

- Not an issue-writing or epic-design substitute; use `issue-create-and-handle` or `epic-composer` first.
- Not permission to implement every open issue in a repository.
- Not a reason to maximize agent count when contract order, resources, or conflicts require sequence.
- Not a release operator for reserved public tag cuts.
