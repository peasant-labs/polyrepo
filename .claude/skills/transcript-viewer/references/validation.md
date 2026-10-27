# Production-path validation

## Know what the browser is running

Establish the worktree, branch, source changes, build output, static/dev server root, mounted
route, application variant, and actual theme. Confirm served bytes or a distinguishing marker.
Repeat provenance checks after rebuilds, server restarts, and switching worktrees.

For reference comparison, use the user's reference and the canonical Fairtrade demo. Do not
substitute a second consumer app as the design oracle. Consumers use the released package unless
the task explicitly authorizes a different integration arrangement.

## Pick the relevant gates

Read the current `package.json`, repository guide, and test sources before running these paths;
commands and inventory can evolve. Typical focused Fairtrade entry points include:

```sh
node scripts/transcript-ledger-turns.test.mjs
node scripts/transcript-reading-layout.test.mjs
node scripts/transcript-ledger-chrome.test.mjs
node scripts/transcript-header-condense.test.mjs
node scripts/transcript-filters.test.mjs
pnpm test:contract
pnpm lint:css
```

The mounted parts gates use `scripts/testdata/*.yaml` and required-name manifests. Their
production mutations run through `scripts/parts-mutations.mjs` with the corresponding gate and
manifest. Header-condense and other focused suites can have their own mutation entry point.
Inspect the actual runner instead of guessing flags or assuming every suite shares a format.

Before a completed implementation handoff, follow the repository's full gate requirements,
including `pnpm build`, `pnpm journey:ci`, and library/parts/package checks relevant to the change.
If a library smoke imports `dist/lib`, build that artifact first. A successful app build does
not imply library output exists. Do not run conflicting builds against the same output directory.

Batch local checks before pushing. Preserve exit status when logging; a pipeline ending in
`tail` can conceal the command's failure. Background commands need realistic timeouts and their
actual completion notification; do not poll or declare them passed while they still run.

## What each level proves

| Evidence | Proves | Does not prove |
|---|---|---|
| Pure adapter/filter fixtures | Normalization, counting, projected membership | Mounted wiring or geometry |
| Mounted production-source tests | State, callbacks, semantics, actual composition | Browser layout or animation frames |
| Named mutations | A specific guard fails for its intended reason | All UI behavior, or unrelated failures |
| Storybook interaction/smoke | A mounted component/story works | Host routing and full production composition |
| Built-app Playwright journey | Real route, controls, layout, theme, motion, focus | User acceptance of the visual result |
| Inspected mounted captures/recordings | Actual visual composition and visible regressions | Behavior not exercised or captured |

When a mutation removes an expected element, report the intended invariant before attempting
to click that element. An unrelated null dereference is not a successful mutation result.
Do not guard away all assertions: absence itself must still fail the behavioral check.

## Motion-specific checks

Use the existing built-app runner for short browser journeys. For example, discover whether
`scripts/journey/transcript-motion.journey.mjs` is present rather than assuming it has landed.
Test normal motion and reduced motion; the runner may default to reduced motion for determinism.

Pause real animations before sampling so a short animation cannot finish before the test under
worker contention. Resume them to observe completion. Keep the unpaused whole-shell journey too:
a paused component test can miss title/timeline insertion, scroll anchoring, and toolbar movement.
Record more than height endpoints: include the neighboring geometry and selection state.

## Capture discipline

- Show persistent chrome plus representative mounted content and the control being changed.
- Include both rendered themes and the affected narrow/desktop layouts.
- Open the image or recording and inspect it. Check its route, build identity, and target before
  claiming that it demonstrates the fix.
- Transient captures stay untracked. For a PR, follow the workspace's durable screenshot-hosting
  rule and keep its screenshot branch alive while the PR is open.
- A passing smoke, an uninspected image path, or a screenshot of the wrong page is not visual review.

## Honest completion

Walk the standing checklist against the consolidated build, including prior user findings.
Separate a green targeted suite from a full green run. If the full run has failures, investigate
and state them; do not relabel them as unrelated or flaky without evidence. Record unresolved
user reports verbatim in the project's tracker/handoff according to repository instructions.
