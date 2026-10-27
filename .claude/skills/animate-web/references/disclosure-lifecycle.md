# Disclosure lifecycle and final-frame flashes

Use this note for collapsible lists, command results, reasoning text, expandable cards, and
header details. Reuse the application's existing primitive; these are lifecycle requirements,
not a second implementation to paste into every component.

## State model

| Phase | Requested open | Content present | Interactive | Painted size |
|---|---|---|---|---|
| Closed | No | Usually no | No | None |
| Opening | Yes | Yes | Yes, unless the product specifies otherwise | Current size toward natural size |
| Open | Yes | Yes | Yes | Natural size |
| Closing | No | Yes until exit completes | No | Current size toward zero |

Allow an explicit keep-mounted mode for lightweight content that must preserve DOM identity.
Do not apply it indiscriminately to expensive code, diff, graph, or syntax-highlighting output.
Changing a list's expansion should not accidentally expand every nested output.

## Timing and ownership

The requested state belongs to the component/host. Presence belongs to the disclosure lifecycle.
Animated pixels belong to the active animation instance. Keep those responsibilities separate.

When a new request arrives:

1. Read the current painted size and opacity, if an animation is active.
2. Cancel the previous animation and invalidate its completion ownership.
3. Make the new contents present if opening; measure the correct natural target.
4. Start from the captured current values.
5. On completion, check that this instance still owns completion before updating presence.

A previous close finishing after a new open must not hide the newly opened content. A previous
open finishing after a new close must not restore it.

## The end-frame bug

An animation normally stops contributing styles when it finishes. If closing content is still
mounted at that instant, its natural height can return before the framework processes the
completion callback. That is a real rendered flash, even when a final screenshot is correct.

Retain the endpoint through the framework commit. With Web Animations, `fill: 'both'` can hold
the endpoint. Commit hidden/presence state first, then remove the retained animation before
paint. On successful opening, also release the animation so the region can grow naturally.

Do not equate a resolved `animation.finished` promise with completed framework rendering. Account
for cancelled animations, component teardown, API absence, and reduced motion. Dispose of every
animation/listener/frame handle owned by the component. If a fallback timer is needed, derive it
from the actual timing, make it cancellable, and do not let it outlive the component.

## Geometry and paint traps

- `display: none` cannot participate in an ordinary height transition. Hide after exit, not before.
- A transformed/scaled box does not move following content like a height change does.
- `height: auto` interpolation support varies; use supported project primitives or measure when
  necessary rather than assuming it works in all target browsers.
- `scrollHeight`, border-box height, margins, and padding measure different things. Do not add
  padding twice or let collapsing margins escape the animated wrapper.
- Overflow clipping is useful during interpolation, but can cut off focus rings and popovers if
  left on after opening. Remove animation-only clipping when the region settles.
- Opened ancestors need natural sizing when a nested output opens. A finished animation retaining
  a fixed ancestor height can clip the child even though its own animation is correct.
- Content can change after measurement. Define how streaming, font loading, images, and nested
  expansion affect the target; do not install an unbounded resize-feedback loop.

## Focus and semantics

On close, remove the region from sequential focus and the accessibility tree immediately. If it
contains active focus, move focus to its controlling trigger before making it inert. Preserve
the trigger's expanded state and its valid relationship with the controlled region.

For reduced motion, perform the same semantic state transition immediately. Do not leave content
waiting for an event that an absent or zero-duration animation will never emit.
