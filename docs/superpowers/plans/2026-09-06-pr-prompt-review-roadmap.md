# PR Prompt Review Roadmap

**Spec:** `docs/superpowers/specs/2026-09-06-pr-prompt-review-design.md`

The spec spans four repositories with a hard ordering fixed by the workspace's
contract ceremony: a wire change is its own schema PR and tag before any consumer
re-pins. Each repository therefore gets its own implementation plan, and each plan
lands software that is useful on its own. Write the next plan only when the plan
before it has tagged or merged, so it can name exact pinned versions instead of
guessing them.

| Order | Plan | Lands | Gate to the next plan |
|---|---|---|---|
| 1 | `2026-09-06-pr-prompt-review-schema.md` | Village API 0.16.0, Local API 0.11.0, Types 0.17.0: `CommandInvocation` on `TurnDetail`, `PromptDigest`, attachment DTOs, the new Village routes. Merged: peasant-labs/schema#107 (develop 8115024); release PR queued | schema release tag minted by the maintainer |
| 2 | `2026-09-06-pr-prompt-review-peasant.md` (to write) | peasant-labs/peasant#323, #324, #325: `Command` emitted through the single conversion path, branch-aware commit association, the push hint, docs | peasant re-pinned and merged; useful without Village |
| 3 | human step | GitHub App re-registered with Pull requests and Checks write scope, webhook URL and secret provisioned per environment | secrets present in each Village environment |
| 4 | `2026-09-06-pr-prompt-review-village.md` (to write) | peasant-labs/village#106 to #113 in arrow order: migrations, webhook receiver, matching, digest, Markdown renderer, routes, PR page, settings | Village re-pinned and deployed |
| 5 | `2026-09-06-pr-prompt-review-fairtrade.md` (to write) | peasant-labs/fairtrade-design-system#76: `PromptDigest` component; Village PR page adopts it | fairtrade release; Village re-pins the package |

Plans 4 and 5 may be executed in parallel once plan 1 has tagged, because the
Village PR page can ship with a plain rendering first and adopt the fairtrade
component when it is published.

Deferred work from the spec (review comments as annotations, PR-scoped read
grants, the Peasant banner, other forges, prompt scoring) has no plan and should
not be started under these plans.

## The epic is the work queue

Every plan above maps to issues under the epic peasant-labs/village#116. The
issues carry the grounded problem statements, acceptance criteria, and
blocked-by arrows; this file only orders the plans. When they disagree, the
issue wins and this file gets corrected.

## How to run one cycle

One session does one plan: one repository, one pull request. State never lives
in a conversation. It lives in the epic, in these documents, and in the
per-plan ledger the subagent-driven process keeps under `.superpowers/sdd/`.

At the start of a session:

1. Run `scripts/sync-all` from the polyrepo root.
2. Read this file, then the epic, then the issue or issues the next plan covers.
3. Check the live state with `gh`: which issues are closed, which PRs are open,
   whether the schema release the plan depends on has tagged. Do not trust
   notes for volatile facts.
4. Pick the highest-priority issue with no open blocker.

During the session:

5. Write the plan at `docs/superpowers/plans/<date>-<topic>.md` with the
   writing-plans skill, arguing from the spec and the issue.
6. Execute it with the subagent-driven-development skill. Implementers and
   reviewers carry the code; the controller keeps only the ledger.
7. Run the whole-branch review, apply its one fix wave, and open the PR with
   `Closes <owner>/<repo>#N` in the body.

At the end of a session:

8. Update the status column in the table above.
9. Make sure every ruling is recorded in the plan or the PR, not only in chat.
10. Leave the worktree committed and pushed. Remove it only after the PR merges.

Kickoff prompt for a new session:

```
Read docs/superpowers/plans/2026-09-06-pr-prompt-review-roadmap.md and
peasant-labs/village#116. Take <owner>/<repo>#N. Confirm with gh that its
blockers are closed. Write the plan with the writing-plans skill, execute it
with subagent-driven-development, then open the PR with Closes #N.
```

Independent issues may run in separate sessions and worktrees at the same time,
one worktree per worker. The Village chain is sequential by its arrows.
