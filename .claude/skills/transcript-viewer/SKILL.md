---
name: transcript-viewer
description: Develop, debug, and review the Peasant Labs web transcript viewer in Fairtrade and its Peasant, Village, and website consumers. Use for transcript cards, grouped model actions, thinking/tool output, reading width and zen, rails and filters, turn selection, scrolling and keyboard navigation, title/timeline transitions, or visual adoption problems. Loads the ownership boundaries, source map, user-ratified interaction rules, production-path validation workflow, and regression pitfalls that prevent repeated UI feedback rounds. Not for backend-only ingestion or the archived transcript-browser application.
---

# Develop the transcript viewer

Treat the transcript as a reading surface over recorded evidence. The user's rendered experience
is the result, not a green test count or a plausible component implementation.

## Start with live truth

1. Read the workspace and target repository `AGENTS.md`. Resolve the actual worktree and branch;
   a directory named `main` does not establish that its checked-out branch is `main`.
2. Read Fairtrade's `PRODUCT.md`, `DESIGN.md`, and `llm/NEUROINCLUSIVE.md`, plus the workspace
   product record. Follow `impeccable` for UI work. Fairtrade is the design authority.
3. Inspect local changes, the relevant handoff, and current tracker/review evidence. Preserve
   unfamiliar work. Verify claims about tests and PR state rather than inheriting them as fact.
4. Identify exactly which application/build the user is reviewing. A consumer of a published
   package does not acquire unpublished library fixes when the library demo is rebuilt.
5. Open the mounted production route and the user's reference. For this reading surface, locate
   `.agents.local/new-transcript-viewer/transcript-ledger.html` in the workspace if available.
   Read its CSS/behavior as well as looking at it. Do not invent a missing reference.

Do not change wire contracts, add migrations, release packages, re-pin consumers, push, or merge
as a side effect of UI work. Follow the workspace ceremonies and the user's explicit boundaries.
Do not silently delete legacy code because it is no longer the design target.

## Ownership and source map

Resolve these paths in the current Fairtrade worktree; the names are a starting map, not proof
that an in-flight refactor has already landed.

| Surface or boundary | Start here |
|---|---|
| Wire parsing and normalization | `src/ui/transcript/adapter.js`, `adapter.parse.js` |
| Cooked model and controlled props | `view-model.js`, `state-capabilities.js` |
| Mounted composition, selection, scroll and host slots | `TranscriptViewer.jsx` |
| Prose turn, role header and system/detail distinction | `TurnCard.jsx`, `SystemRow.jsx` |
| Grouped action list and counts | `WorkGroup.jsx`, `work-summary.js` |
| Tool header and output rendering | `ToolCall.jsx`, `ToolBody.jsx`, `TaskBody.jsx` |
| Thinking row and output | `Thinking.jsx` |
| Disclosure animation lifecycle, when present | `Collapsible.jsx` |
| User-turn outline and current-task card | `OutlineRail.jsx` |
| Category projection and filter controls | `filters.js`, `FiltersRail.jsx` |
| Reading-line lookup and initial/restore behavior | `scroll-position.js`, `initial-position.js`, viewer hooks |
| Canonical styling and tokens | `src/index.css` |
| Built demo composition and representative data | `src/mockups/inuse/TranscriptApp.jsx` |

Schema owns the shared wire contract. Both backends produce it; Fairtrade's `adaptTranscript`
owns the wire-to-view-model boundary. Consumer apps supply routing, consent, permissions, data,
and host slots. They do not reimplement transcript parsing or fork canonical components/styles.
The archived `transcript-browser` repository has no runtime role.

Keep rendering on cooked model fields. Do not parse raw tool JSON inside components, manually
recreate shared rules in consumers, or fabricate recorded evidence. A timestamp gap can include
tool execution, network latency, and harness overhead; it is not automatically an exact thinking
duration. Omit unknown timing, or obtain agreement on an honestly described estimate. A field
existing in a demo model does not prove the producer sends it.

## Reading-surface contract

Use [references/regression-checklist.md](references/regression-checklist.md) as the standing
review checklist, including the user's own wording. Recheck the whole applicable checklist
against the current consolidated build, not just the latest changed component.

### Turns and grouped work

- Only a turn with prose gets a prose card. Thinking-only and tool-only agent turns are inline
  detail: no visible role well, number, or timestamp. Preserve their anchors and accessible names.
- The prose header carries role, number, time, copy link, and host `renderTurnActions`. Do not
  reintroduce built-in model/token/error/label/collapse controls there merely because old code has them.
- Group model work by **user turn**, across intermediate prose and wordless agent turns. Place
  the block after that user turn's first model prose card; handle a group with no prose explicitly.
- Suppress every member's original work rendering, including the hosting prose turn's own work.
  A grouped action must not appear once beside its prose and again inside the block.
- Determine user-turn ownership from stable source identity before display projection. Hiding
  prompts must not merge work from different user turns just because separators disappeared.
- An action block is not a turn. It does not acquire the active-turn bar or a `j/k` keyboard stop.
- Show the action list by default, with individual contents closed. Compact mode collapses the
  lists. The list can still be opened explicitly; a previously open child must not hold it open.
- The block is unboxed and has no `model actions` label. Its summary uses the agreed action/count
  wording, for example `2 actions: 2 commands, 13s`, without a redundant `calls` total.
- Use the same row geometry for tool kinds and `Think`: kind icon/name, preview or word count,
  and supported timing. No disclosure chevron on these rows. Keep heights, insets, and spacing
  consistent when badges appear or a child opens. Count concepts deliberately, not by DOM wrappers.
- Expanded output belongs in a box; the action row and group do not. No horizontal rule appears
  between a row's header and its expanded body. Preserve literal line breaks and safe text escaping.
- Bash input has an `input` label above its box. Keep the `$` prompt, not a second terminal icon
  inside that box. Do not alter the recorded command to add chrome.

### Selection, rails, width, and filters

- Clicking a prose card selects it and moves the amber active marker without jumping the reader.
  Hover changes its background, not its selection. Preserve the reference's entry/exit fade through
  canonical tokens and reduced-motion rules. Keep nested controls usable.
- When passive reading enters another user turn, bring its current rail card into the rail's
  viewport at the nearest edge. Scroll only that rail; do not focus it or move the page.
- User-turn cards run to the outline body's edges, retaining their own text inset. Do not remove
  the padding required by unrelated outline tabs or the right filters panel.
- The width handle hugs the actual reader's trailing edge, widens and narrows, and rests where
  released: no snapping. Its maximum is the available middle content width up to the control lane,
  not a fixed desktop cap. Re-measure when the window, rails, or host layout change.
- Width changes never reopen/collapse sidebars. Zen snapshots and restores the exact prior layout,
  including the host sidebar; it is not permission to reset every panel to defaults.
- A host per-turn panel and commit marker belong inside the reading column's row wrapper, not
  directly against the scroll container's far-left edge. Test the host's real rendered slot.
- Filters project visible parts through the canonical filter evaluator. A checkbox that only
  changes state or counts while rendered content remains unchanged is broken.
- System turns have their own checked-by-default category. Missing `system` in older saved or
  host-controlled filter state means enabled. Unchecking hides only system turns; counts,
  active-filter badges, rechecking, and clear/reset must agree with the actual mounted projection.

## Scrolling and animation

Read `../animate-web/SKILL.md` for motion implementation and debugging.

Preserve the title/breadcrumb distinction: the large session title can leave while the breadcrumb
and actions remain. The pinned timeline does not need another copy of the title. Treat the entire
title/timeline/toolbar/stream geometry as one transition; an individually smooth title does not
prove the shell no longer jiggles.

Keep a requested keyboard selection separate from passive reading-line tracking. Smooth-scroll
events must not reset it to a previous turn, particularly at clamped top/bottom positions. Bursts
need a current logical cursor, not a stale render closure. Test overshooting both ends and then
reversing direction, short cards, filtered detail turns, and manual-scroll takeover.

Preserve anchors, partition-scoped identities, stable tool IDs, search reveal, initial position,
return-from-other-tab scroll restoration, rail state, and host callbacks. Use real routes and
callbacks, not dormant legacy components, to establish that these still work.

## Visual language and trust boundaries

Use Fairtrade tokens, square shapes, scarce amber, the documented type scale, tabular counts,
Atkinson fonts loaded by layout head links, and both themes. Keep user content's case intact;
chrome casing rules must not lowercase paths, commands, provider identifiers, or transcript prose.
Provider identity uses the existing brand component, not a generic replacement glyph.

Syntax highlighting stays structured: `codeToHast` or `codeToTokens`, validated and rendered
through React. Never introduce highlighter HTML injection to make output animation easier.
Keep publication consent, fail-closed redaction/share behavior, canonical `/share`, and host-owned
permission gates intact while changing transcript chrome. Do not remove a production exit.

## Validation workflow

Read [references/validation.md](references/validation.md) before reporting completion.

1. Confirm the changed behavior exists in a representative fixture and the mounted route. Include
   multiple prose turns for one user, wordless turns, thinking, a tool error, system notices, long
   content, host slots, and enough user turns for the outline to overflow where relevant.
2. Add/update named YAML fixtures and required-name manifests. Assert observable outcomes and
   exact membership where appropriate; do not add inline permutation tables or count-only guards.
3. Run focused production-source tests and their named mutations. A null-selector crash under a
   mutation does not prove the intended invariant; preserve the intended diagnostic.
4. Verify computed styles, layout, interactions, and motion in the built app. Check both themes,
   desktop and affected narrow layouts, real nested controls, scroll boundaries, and reduced motion.
5. Run the repository's required build, contract, parts, library, and Playwright gates from the
   exact worktree. Inspect failures rather than assuming a prior green summary still applies.
6. Inspect captures of the complete mounted shell and representative body. Confirm the served
   assets match the source under review. Storybook supplements, but does not replace, product proof.

Do not solve a validation failure by hiding the offending UI, weakening a gate, changing the
reference to match a defect, or asking the user to serve as the regression backstop. A user report
of remaining jiggle is actionable even if a component-level animation test passes.

## Handoff

State the exact source/worktree and served build, what was checked, which user findings are still
open, and whether changes are local, pushed, merged, released, or adopted by consumers. These are
different states. Keep volatile versions, heads, PR state, and test totals in live task/handoff
evidence, not copied into this skill. Never infer permission to push or release from a UI approval.
