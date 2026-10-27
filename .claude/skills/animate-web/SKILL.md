---
name: animate-web
description: Implement, inspect, and debug web animation and microinteractions, including hover fades, reversible expand/collapse, lazy output rendering, sticky-header transitions, scroll-linked selection, and reduced motion. Use whenever a web UI should feel smoother, flickers or flashes content, jiggles during layout changes, jumps on reversal, or gets stuck during repeated keyboard navigation. Follow the project's design system and verify the mounted production interaction, not just endpoint screenshots.
---

# Animate web interfaces

Make state changes understandable without moving the interface twice, flashing its contents,
or making the reader fight the scroll position. Preserve the requested interaction and the
project's visual language. A smoother animation is not permission to redesign the surface.

## Establish the motion contract

1. Read the repository instructions and its product, design, accessibility, and motion records.
   In this workspace, UI work also follows `impeccable`; Fairtrade remains the visual authority.
2. Inspect the actual mounted surface and any supplied reference HTML. Read the reference's
   CSS and handlers: `transition: background .12s` uses the default `ease` curve, which is not
   interchangeable with the design system's custom ease-out curve.
3. Name the trigger, logical state, animated element, affected siblings, start/end geometry,
   interruption behavior, reduced-motion behavior, and cleanup. Include the surrounding shell.
4. Reuse existing tokens and disclosure primitives before adding a helper or dependency.
   For Peasant transcript work, also read `../transcript-viewer/SKILL.md`.

Keep content visibility, presence in the DOM, and animation progress separate. A list can be
expanded while every item's contents remain closed. A closing region can still be painted
while already unavailable to keyboard and assistive technology.

## Choose the smallest mechanism

| Interaction | Starting point | Avoid |
|---|---|---|
| Hover background | CSS transition on the resting rule, fine-pointer hover | Transition only on `:hover`, so exit snaps |
| Icon or small positional feedback | Existing transform/opacity motion | Moving surrounding layout unnecessarily |
| Disclosure that moves following content | Existing collapsible; measured height or suitable CSS layout interpolation | Scaling the text; guessed `max-height` ceilings |
| Interruptible, lazy-mounted output | Presence-aware disclosure using the existing animation stack | Unmounting before exit; eager rendering of every hidden output |
| Title replaced by pinned chrome | One coordinated layout transition | Independently inserting and removing rows without accounting for their space |
| Deliberate jump to a turn | Native scrolling plus explicit selection intent | Wheel interception or global smooth scrolling as a substitute for fixing state |

Animating height can be appropriate when siblings must genuinely move. Keep measurement
bounded, batch layout reads before writes, and avoid measuring every hidden item on scroll.
Do not prescribe a new duration or curve when the project already owns them. Never use
`transition: all` to animate unrelated state changes accidentally.

## Build reversible disclosures

Read [references/disclosure-lifecycle.md](references/disclosure-lifecycle.md) before implementing
or changing a collapsible region.

The critical sequence is:

1. Mount expensive content only when needed. Measure the actual opening geometry after it exists.
2. On close, preserve the painted content long enough for the exit. Mark it `aria-hidden` and
   inert immediately; if focus is inside, return it to the disclosure trigger before hiding it.
3. On interruption, read the current painted height and opacity **before** cancelling the old
   animation. Reverse from those values, not from an endpoint.
4. Ignore completion callbacks belonging to a superseded animation. Handle cancellation and
   unmount without stale state updates, retained listeners, or unhandled rejected promises.
5. Preserve the final keyframe until the framework has committed the hidden/unmounted state.
   With Web Animations, an appropriate fill mode can bridge that commit. Releasing the fill
   inside the completion callback too early can expose natural height for one frame.
6. After the commit, release animation-owned sizing before paint. An opened region must return
   to natural height so nested outputs, font loading, images, and streamed content can grow.

**Incorrect:** cancel the closing animation, then asynchronously set the content absent. The
browser can paint the complete contents between those operations.

**Correct:** retain the closing endpoint through the hidden commit, then cancel the retained
animation in the framework's layout/commit phase. Verify the actual handoff in a browser.

Do not keep permanent pixel heights or a permanent fill effect merely to hide the flash.
Do not copy an entire existing component into a second animation implementation.

## Coordinate layout and scrolling

Read [references/layout-and-scroll.md](references/layout-and-scroll.md) for title/timeline
replacement, scroll anchoring, and rapid-key navigation.

- Follow the positions of the **header, replacement row, stream, and first visible content**,
  not just the disappearing title's height. One element can animate monotonically while its
  parent or sibling still jumps.
- Determine which elements are in flow, absolute, or sticky. Account for the replacement row's
  occupied height exactly once. Do not animate a temporary extra row and remove it afterward.
- Keep threshold and overflow guards stable through the transition. Do not treat a mid-animation
  height as the expanded baseline, or let reflow repeatedly cross the trigger threshold.
- Inspect scroll anchoring before changing it. Disable or compensate only where needed; a global
  change can break reading-position preservation when content above the reader expands.
- Do not alter normal wheel/touch behavior to mask a header-layout problem.

For explicit keyboard navigation, update a synchronous logical cursor before scheduling a
scroll. React render state alone can be stale during a burst of key events. Smooth-scroll
feedback must not replace the requested selection with an intermediate reading-line candidate.
At an edge, the target may never physically align with the reading line. A clamped scroll
position is not a reason to reject a valid next/previous selection.

Coalesce obsolete scheduled jumps, make repeated keys at a logical boundary harmless, and let
real wheel, touch, scrollbar, or native page-navigation intent resume passive scroll tracking.
Respect editable controls, nested keyboard handlers, and `event.defaultPrevented`.

## Accessibility and restraint

- Preserve semantic buttons, `aria-expanded`, valid control IDs, and keyboard access. Do not
  turn an entire card containing links and buttons into another nested button.
- Keep selection, focus, hover, and expansion distinct. Hover must not select, scroll, or shift
  layout. A selected state needs its own non-color indication where the project requires it.
- Scope hover to devices that can hover. Put the transition on the element's resting rule so
  both entry and exit use it.
- Honor `prefers-reduced-motion` for JavaScript animation as well as CSS. CSS overrides do not
  automatically cancel a Web Animations API animation. Preserve all final behavior without
  motion; test preference changes during an active animation if that case is supported.
- Keep the interface usable if animation APIs or motion tokens are unavailable. Avoid loading
  flashes during hydration and unwanted entrance animations on initially open content.

## Verify motion, not just screenshots

1. Reproduce on the actual route and served build. Confirm a distinguishing source marker or
   asset fingerprint before trusting the browser. Check after server restarts and rebuilds.
2. Test entry, exit, reversal, rapid repeated activation, both scroll limits, and nested outputs.
   Include both themes and the viewport classes affected by the change.
3. Use unit/mounted tests for state and callbacks. Use a real browser for geometry, animation
   timing, focus, and final-frame flashes; jsdom cannot prove those.
4. Sample beginning, midpoint, endpoint, and several frames **after** completion. In tests, pause
   the real production animation before it can finish, seek to sample times, then resume it to
   observe the real framework handoff. Do not replace the animated component with a mock.
5. Account for numeric serialization: `cubic-bezier(.77,0,.175,1)` and
   `cubic-bezier(0.77, 0, 0.175, 1)` describe the same curve.
6. Avoid test races against a short duration under many workers. Do not fix a race with a longer
   arbitrary sleep or a longer production animation. Record measurements and test the intended
   failure, including completion ownership and cleanup.
7. Inspect actual screenshots or recordings of the complete mounted surface. A screenshot of
   the docs page instead of the target, or a final still image, does not establish motion quality.

Use the existing browser runner and fixture conventions. Keep cases in fixtures and protect
required names. Do not build a new screenshot or process orchestration system for a small effect.
Inspect in a bounded batch, fix the findings together, and confirm once rather than polishing
indefinitely. User-reported jitter remains unresolved until the full interaction is rechecked.

## Handoff

Report what changed, which real interactions were verified, what remains uncertain, and whether
the served app contains the change. Distinguish passing state tests, browser motion evidence,
and the user's acceptance. Do not promote a plausible cause or a component-only success into a
claim that the entire title/timeline transition is fixed.
