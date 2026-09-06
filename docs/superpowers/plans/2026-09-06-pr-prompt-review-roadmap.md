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
| 1 | `2026-09-06-pr-prompt-review-schema.md` | Village API 0.15.0, Local API 0.10.0, Types 0.15.0: `CommandInvocation` on `TurnDetail`, `PromptDigest`, attachment DTOs, the new Village routes | schema release tag minted by the maintainer |
| 2 | `2026-09-06-pr-prompt-review-peasant.md` (to write) | `Command` emitted through the single conversion path, branch-aware commit association, the push hint, docs | peasant re-pinned and merged; useful without Village |
| 3 | human step | GitHub App re-registered with Pull requests and Checks write scope, webhook URL and secret provisioned per environment | secrets present in each Village environment |
| 4 | `2026-09-06-pr-prompt-review-village.md` (to write) | migrations, webhook receiver, matching, digest, Markdown renderer, routes, PR page, settings | Village re-pinned and deployed |
| 5 | `2026-09-06-pr-prompt-review-fairtrade.md` (to write) | `PromptDigest` component; Village PR page adopts it | fairtrade release; Village re-pins the package |

Plans 4 and 5 may be executed in parallel once plan 1 has tagged, because the
Village PR page can ship with a plain rendering first and adopt the fairtrade
component when it is published.

Deferred work from the spec (review comments as annotations, PR-scoped read
grants, the Peasant banner, other forges, prompt scoring) has no plan and should
not be started under these plans.
