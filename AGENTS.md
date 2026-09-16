# peasant-labs — polyrepo guide for agents

`peasant-labs/polyrepo` is a **multi-repo workspace**: independently-versioned git
repositories developed together. This file carries the workspace map, cross-repo rules, and
ratified invariants; repo-specific detail lives in each repo's own `AGENTS.md` — read that first
when working in a repo. (The root also hosts other repos — `bestiary`, `reeve`, `provenance`,
`website`, `zone`, `homebrew-tap`, … — not covered here.)

**Volatile facts are never restated in prose.** Pins, releases, spec versions, and PR/issue
states are derived from `go.mod` / `package.json` / `gh` at the moment of work; the only
point-in-time notes allowed are the dated digest at the end of this file.

## Layout & shared infrastructure

- **git-worktree workflow per repo:** `<repo>/` is the worktree *host* on a throwaway
  `__dummy__`/`dummy` branch — never commit or push it. Feature work lives in worktrees
  `<repo>/<branch>` (nested children under `<repo>/<branch>/worktree/…`), not the host.
  **Default branches:** peasant, village, schema → `develop` (peasant/village reserve `main` for
  releases); fairtrade, redact, transcript-browser → `main`.
- **`flake.nix` + `.envrc` (direnv)** — the Nix devShell.
- **`llm/`** — cross-repo, LLM-facing planning docs (fairtrade adoption playbooks, research).
- **Remotes (peasant): `peasant-labs/peasant-prerelease-archive` (frozen pre-launch
  history), `peasant-labs/peasant` (live).** Bare `gh pr/issue <n>` resolves
  against the archive, whose numbering overlaps the live repo — always pass
  `-R peasant-labs/peasant`, and hand subagents a local git range, never a
  bare PR number.

## The core repos

| repo | role | start here |
|---|---|---|
| **schema** | canonical wire contract: Go module + generated TS package `@peasant-labs/schema` (npm) | `schema/develop/AGENTS.md` |
| **redact** | canonical redaction engine (`github.com/peasant-labs/redact`), pinned by both backends | `redact/main` (no guide yet) |
| **fairtrade-design-system** | canonical design system + transcript UI (`@peasant-labs/fairtrade`, npm) | `fairtrade-design-system/main/AGENTS.md` |
| **peasant** | the engine room: ingests, indexes, serves agent sessions; emits `session_detail` | `peasant/develop/AGENTS.md` |
| **village** | the transcript commons: registry, access control, discovery (Postgres/S3) | `village/develop/AGENTS.md` |
| **transcript-browser** | **ARCHIVED — no runtime role; do not add work here.** Its former holdings live in fairtrade. | — |

- **schema:** village serves AND enforces the spec from the module (served ≡ enforced,
  un-driftable). Retired spec versions are byte-frozen; specs bump, never mutate. The handwritten
  `@peasant-labs/types` port is deprecated — never add wire definitions there. Versioning
  procedure, codegen/freshness gates, npm-publish runbook: its `AGENTS.md` + `docs/release-runbook.md`.
- **redact:** owns the redaction categories, rules, canonical fixtures, and rule-set versioning
  (extracted from peasant's former `pkg/redact`); peasant's `internal/config` owns the level-offer
  policy layered on top.
- **fairtrade:** single source of truth for ALL theming + transcript-component decisions —
  consumers conform, never redefine canonical values. Exports token/base/component CSS, `/icons`,
  `/ui` (primitives, the composite `TranscriptViewer`, and the **one** adapter `adaptTranscript` —
  the sole wire-parse + git-normalization boundary) plus the `@xyflow` graph engine. Design
  language + a11y: its `llm/DESIGN.md` + `llm/NEUROINCLUSIVE.md`.
- **peasant:** key areas `internal/ingest` (CommitDetector, pipeline), `internal/transcript`
  (`EntriesToTurns`), `internal/api` (the `session_detail` WS), `internal/store` (SQLite,
  `session_commits`), `web/`. Its guide carries the ratified product invariants (redaction
  policy, session selection, git-history model, share UX).
- **village:** consumes the schema contract as the ENFORCER (validates inbound publishes against
  the pinned spec). Licensing + governance: CC menu on publish/PATCH, fail-closed trigger-written
  governance audit (`app.actor_id` GUC, append-only), un-license irrevocability. Deep refs in its
  guide: `TESTING.md`, `docs/database-invariants.md` (invariant changes update that doc in the
  same commit).

## How they connect

```
             schema (wire contract: Go module + generated TS package)
               │ defines the wire          redact (redaction engine)
 produced by ▼                              ▲ pinned by both backends
 peasant backend ── session_detail ──►  peasant web
 village backend ── (same contract) ──► village frontend
                                         │ both frontends render via fairtrade:
                                         ▼ transcript viewer + adaptTranscript + @xyflow
```

- **Data:** schema defines the wire → both backends emit `SessionDetailPayload` → both frontends
  render it via fairtrade's `adaptTranscript`. Transcript rendering belongs to fairtrade; consumers
  are adapters, never re-implementations.
- **Licensing:** the menu is owned by the contract (`schema.AllLicenses`: `CC0-1.0` / `CC-BY-4.0` /
  `CC-BY-SA-4.0`) → village ENFORCES it (publish/PATCH + governance audit) → peasant mirrors it in
  two SQLite closed-set CHECK tables (accept-sets derived from `schema.AllLicenses` in tests, so
  widening goes red until one migration rebuilds both tables — SQLite cannot ALTER a CHECK) and
  displays it end-to-end. Canonical widening procedure: village `AGENTS.md` → "Adding a license".
  Licenses form a PARTIAL order (no rank, no computed meet); un-licensing is blocked app-side (CC
  grants are irrevocable).
- **Contract ceremony (hard rule):** a wire-contract change is its own schema-repo PR + tag BEFORE
  the consumer PRs re-pin it; the redact module follows the same tag-before-re-pin pattern. Stated
  in both the peasant and village guides.
- **Schema changes are the expensive, high-risk path (hard rule):** treat any schema change — the
  shared wire contract in `schema` **and** a database migration in either backend — as more costly
  and higher-risk than an ordinary frontend or backend change. Both are surfaces other code reads:
  the wire contract is consumed across repos and needs its own PR + tag before a consumer re-pins
  it, and a shipped migration is immutable and effectively irreversible in production, so a wrong
  column, index, or CHECK is a forward-only fix. Do not reach for one when a non-schema change
  would do; when one is genuinely needed, say so up front, expect the slower review (contract
  gates, migration + invariant tests, zero-diff codegen), and batch it with other pending changes
  rather than cutting one per change.

## Conventions

- **Worktree naming:** `<primary-repo>-<issue#>--<semantic-commit>--<descriptive-name>`, the
  *primary repo* being the one the change centers on; a cross-repo epic reuses that one name
  across every participating repo's worktree.
- **Landing:** squash the epic branch → `merge --no-ff` into the repo's default branch. After a PR
  merges: sync the local default worktree (`git -C <repo>/develop pull`), run the repo's normal
  build from the freshly synced worktree before creating new feature worktrees from it (peasant:
  `make build`), remove the merged worktree, and delete its remote branch. Verify merges via
  `gh pr view <n> --json state,mergeCommit`, not a possibly-stale local ref.
- **No git hooks** (hard rule). Nix devShell via `flake.nix`/direnv.
- **Link every PR to its issue explicitly — GitHub only does it for you on the happy path.** A
  closing keyword (`Closes #N`) in the PR body links the PR under the issue's Development section
  **only when the PR merges into the default branch**. A stacked PR (base is another feature
  branch) and a partial PR (`Part of #N`) therefore get no link, and the issue silently carries a
  body-only reference. So after opening any PR whose base is not the default branch, add the link
  yourself with the same mutation the UI's "Link a pull request" uses:
  ```sh
  issue=$(gh api repos/<owner>/<repo>/issues/<n> --jq .node_id)
  pr=$(gh api repos/<owner>/<repo>/pulls/<pr> --jq .node_id)
  gh api graphql -f query="mutation { addCloseIssueReferences(input: {issueId: \"$issue\", pullRequestIds: [\"$pr\"]}) { issue { number } } }"
  ```
  It is idempotent, so re-running it on an already-linked PR is harmless. Do this at open time, not
  later: a stacked PR is exactly the case where the reviewer never sees the issue link.
- **Ship a multi-PR change as a real GitHub stack (public preview, enabled on this org).** A branch
  chain is not automatically a stack; make it one so the merge is ordered and the upper layers
  re-target themselves. After opening the PRs (bottom first, each based on the one below):
  ```sh
  gh api repos/<owner>/<repo>/stacks -X POST \
    -F 'pull_requests[]:=<bottom-pr>' -F 'pull_requests[]:=<top-pr>'
  ```
  (the `:=` matters: `-f` sends strings and the endpoint requires integers). Read it back with
  `gh api repos/<owner>/<repo>/stacks/<stack-number>` or GraphQL `pullRequest { stack { number } stackEntry { position } }`.
  **Merging a stack cannot use `gh pr merge`** — the legacy endpoint refuses it. Use the async API,
  which merges every PR up to and including the one requested, then poll the returned UUID:
  ```sh
  gh api repos/<owner>/<repo>/pulls/<top-or-any-pr>/merge-async -X PUT \
    -F merge_method=squash -F 'commit_title=<title>'
  gh api repos/<owner>/<repo>/pulls/<pr>/merge-async/<uuid>   # poll until it reports a result
  ```
  Merge requirements for the whole stack come from the BOTTOM PR's base branch (so `develop` rules
  and CI apply to every layer), and a stack merge is atomic. `--force-with-lease` on a stacked branch
  is fine after a rebase: rebases are expected in a stack, and the branch is not shared.

- **Literal Markdown in shell commands:** protect Markdown passed through a shell (`gh issue
  comment`, `bd comments add`) from expansion — a single-quoted argument or safely quoted file
  input; never unquoted backticks/`$`/globs. Verify the published comment if the command reports
  shell errors.
- **Structured syntax-highlighting output only (hard security boundary):** never call Shiki's
  `codeToHtml()` or inject highlighter HTML with `dangerouslySetInnerHTML`; use only
  `codeToHast()`/`codeToTokens()`, validate the structured result, and render through React so
  untrusted transcript/tool-output text stays escaped. Keep the source guard green (fairtrade:
  `scripts/assert-structured-shiki.mjs`).
- **Generated files are never hand-merged:** on conflict (sqlc output, schema-gen goldens,
  lockfiles) merge the SOURCE, keep the target's generator config, and RE-RUN the generator —
  committed output must be byte-identical to fresh codegen under the pinned generator version
  (zero-diff regen).
- **Release tooling is partly duplicated across peasant + schema** (`scripts/update-nix-vendor-hash.sh`,
  release-pr/release workflows; release-guard is single-sourced in the schema module and tooled by
  peasant, and fairtrade carries its own JS guard). When touching one copy, diff the sibling.
- **CI and releases are budget-constrained (a small student org, not a big one):** do not cut a
  release per contract change, and do not open or re-push PRs casually. Batch one schema release to
  cover every pending contract change a consumer needs, and cut it only when a consumer actually
  re-pins — hold the tag otherwise. Prefer one larger PR over several small ones, run the local
  equivalents before pushing, and push once per change rather than iterating through full CI runs.
  (For scale: a village PR push runs four jobs including a ~5-minute PostgreSQL+MinIO aggregate; a
  schema push runs `make check` (~7 minutes) plus the contract gates.)
- **Shipped-artifact hygiene (worker-prevented):** no internal task taxonomy — Beads IDs,
  slice/leaf-task names, phase or epic codenames — in shipped code, comments, docs, or commit
  messages; describe everything by substance. Self-grep the changed files for taxonomy tokens and
  scrub any hit before reporting work complete (`.tb-*` CSS selectors are real DOM names, not
  taxonomy).
- **Test cases live in FIXTURES, never inline (all roles, all phases):** combinatorial /
  table-driven / permutation cases go in `testdata/*.yaml` fixtures (the typed struct +
  `//go:embed` + `yaml.Unmarshal` + `Load…Fixtures()` idiom). Deletion protection uses
  required-NAME manifests, never bare counts — count guards churn on every addition and conflict
  across parallel slices. Closed/security sets assert exact set MEMBERSHIP; a bare count is
  acceptable only when the count itself is the contract, stated in the fixture. Architects plan
  validation cases as fixtures; workers implement them that way by default; any inline case table
  is a review finding.
- **Do not delete real prior-version functionality just because the persistent chrome changed:**
  soft-retain real user flows as deprecation candidates and keep production evidence exits
  working; delete only genuinely dead scaffolding, never-shipped experiments, or orphan wiring.
  If it is unclear whether something is user-facing, surface the decision before removing it.
- **Production exits are tested on the mounted production path** — assert the actual navigation or
  callback users trigger, not dormant legacy components.
- **Interface-changing PRs include mounted screenshots for review:** capture the changed mounted
  production path in both themes from the exact PR branch, verify the served build's provenance,
  inspect the images for regressions, and embed durable GitHub-hosted screenshots in the PR body.
  Storybook-only captures, local-only paths, and uninspected screenshots do not satisfy this gate.
  Transient PNGs stay untracked; only committed `baseline/` regression references are tracked.
- **"Shell" means chrome plus mounted body, not a nav strip:** persistent product header, section
  navigation, active-section state, route/view wiring, and representative body content. Gates fail
  closed when either side is missing or blank.
- **Shared SxS visual gates compare the canonical fairtrade demo (left/reference) to the current
  consuming app (right)** — never app-to-app unless that is the explicit regression target.
- **Graph app section order is canonical:** `analytics | changes | code map`, owned by fairtrade
  (`GRAPH_APP_SECTIONS` in `src/ui/inuse/InUseShell.jsx`); consumers derive from it and fail
  loudly on unknown or unmapped section IDs rather than silently dropping sections. Binding until
  a replacement is user-ratified and lands in Fairtrade first.
- Workers should commit early and commit often using atomic commits and conventional commit messages.

## Review & UAT discipline

The user is NEVER the backstop for a repeat finding or a design-system violation. Mandatory:

- **The live in-use demo is the fidelity oracle** — match it element-for-element; when the demo
  and the DS docs conflict, match the demo and file the conflict as a DS-repo followup (do not fix
  it inside an adoption). Flag app↔demo divergences and genuine gaps, not demo-faithful matches
  that happen to violate a doc.
- **Be design-system-literate before reviewing any fairtrade surface:** read fairtrade's own docs
  — its `AGENTS.md` (hard invariants), `llm/DESIGN.md` + `llm/NEUROINCLUSIVE.md`,
  `src/sections-react/*` — to understand intent and resolve ambiguity. A surface that violates a
  documented invariant is a finding even if it "looks close": Atkinson Hyperlegible fonts via a
  `<link>` in the layout head (never a remote `@import`), provider names leading with
  `<BrandMark>`, all-lowercase UI chrome (never lowercased user content), tabular numbers on
  counts/durations, radius 0, tokens only, amber as a scarce accent, two WCAG-AA themes, 16px body
  floor / mono-14 chrome, neuroinclusive defaults, no AI-slop.
- **Every user eyeball/UAT finding is recorded VERBATIM in beads and carried forward as a standing
  regression checklist;** every re-review walks the ENTIRE prior checklist against the CURRENT
  build — reviewing a slice only against its own fix-spec, in isolation, is how repeats slip.
- **Never work around a gate instead of fixing the finding, and never trust a mount-only gate.**
  Do not hide flagged elements from captures; assert the actual rendered thing (computed
  `font-family`, computed layout/styles) on the CONSOLIDATED integration build.
- **Verify build provenance before trusting any capture:** grep the served `dist`/`out` for a
  string only the fix introduces and confirm which source the server actually resolves — a stale
  server or wrong worktree silently invalidates a shot. A "timing artifact" between reports is
  the same bug class: recapture fresh and name the exact build under test.
- **Unconsolidated slices are invisible to a body-only audit:** confirm every intended slice
  actually landed on the integration branch and is present in the built artifact (grep the DOM for
  marker classes, check route/Navbar wiring) — "reviewers accepted the body" ≠ "the app ships it."

## Product invariants (summaries — full detail in `peasant/develop/AGENTS.md`)

- **Redaction:** categories are `secrets` / `pii` / `paths` / `project` (git remotes, import
  paths, Docker refs, branch names, and CI project variables are `project` — no separate
  git-context category); activation policy is independent of category; rendered labels come only
  from the engine's `Category.String()`; unknown categories fail closed at trust boundaries.
  Levels: `standard` is the only offered level, `minimal` is accepted-but-raised, `maximum` is
  refused.
- **Kickstart selection:** `ingest.SelectionMatcher` is the canonical matcher (server-side; never
  reimplement in React). Selection scopes DISCOVERY/LISTS only — it is NOT an access-control
  boundary: already-stored sessions stay deep-link-viewable, historical rows are removed only by
  manual `peasant prune`, and publishing is user-initiated (`/share`) from the user's own recorded
  sessions only.
- **Git history ↔ sessions:** the target is Git as the timeline spine annotated with associated
  user sessions (bound vs candidate associations kept distinct; unattached sessions discoverable);
  the `changes` label and `/review` routes remain in force until a replacement is user-ratified —
  never silently rename or delete them. Wire changes follow the contract ceremony.
- **`/share` is canonical** (no `/push` alternate route) and stays OUTSIDE fairtrade's
  graph-section registry; share-bridge scan/cache/fail-closed semantics must be preserved across
  UI changes. Fairtrade owns the official review/redaction/consent/share composition
  (fairtrade-design-system#3, per-category `RedactionReview` filtering #4).

## Visual / screenshot UI harness

Each app repo carries a headless-Chrome/Puppeteer capture harness: shoot a surface in **both
themes**, shoot the fairtrade **demo** for the same surface, stitch side-by-side (SxS), eyeball
against the demo, probe computed styles, and diff against the tracked baseline.

- **Locations:** village `frontend/scripts/visual/` · peasant `web/scripts/visual/` · fairtrade
  `scripts/` (its tracked regression references live at the repo root in `baselines/`).
- **Primitives — duplicated per-surface and per-repo (consolidation into one parameterized toolkit
  is a tracked followup):** boot (start the app or real binary on a fixed port) · mock (fake
  backend REST/auth) · shoot (screenshot per surface × theme) · stitch (demo↔app SxS) · diff
  (pixel-diff vs committed baseline) · probe (`getComputedStyle` assertions — the definitive token
  check) · gate (pass/fail wrapper).
- **Discipline:** verify computed styles, not just pixels (close-value token pairs are
  indistinguishable in scaled PNGs); verify build provenance before trusting any capture (see
  Review & UAT discipline); both apps resolve fairtrade from the published npm registry, never a
  local dev-link; capture outputs go to `review-capture/` or `/tmp` — never commit per-round proof
  PNGs.
- **Screenshot paths are one-line output:** present a related screenshot set as exactly one
  Markdown line containing one absolute path expression with `{...}` brace alternatives for the
  theme/surface/demo-app axes, structured so every expansion names an existing artifact.

## Digest (2026-09-02 — non-derivable state only; everything else from manifests + gh)

- Peasant/village `main` advances only on paper: release tags are cut from `develop`, and `main`
  has not moved since the first release (open decision: automate the fast-forward or drop the
  convention).
- The release-PR maintainer-approval assertion is disabled in both peasant and schema (single
  active maintainer; GitHub no-self-approval); each repo's runbook §6 carries the re-enable
  checklist.
- The visual-harness scripts remain per-surface/per-repo duplicates — no shared toolkit yet.

