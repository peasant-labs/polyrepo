# Standing transcript UI regression checklist

These are the design decisions and failure modes elicited during the reading-surface iteration.
Quoted wording is historical user evidence, not a claim that the current checkout implements or
has passed every item. Confirm later user decisions before applying an older rule.

## Source evidence and distinct builds

- A library demo and a consumer pinned to a published package can legitimately show different
  versions. Identify the source of the user's screenshot before blaming cache or declaring a fix.
- The demo may serve built files through a plain static server. Source edits alone then change
  nothing. Rebuild, verify new asset bytes, and navigate to the correct route.
- A browser hash does not prove the target is in the viewport. Inspect the screenshot: capturing
  documentation farther up the same long page does not show the transcript.
- A demo tool copied from another turn can repeat a command even after the grouping bug is fixed.
  Use distinct identities and commands in fixtures so data duplication and rendering duplication
  are distinguishable.

## Grouping and content

> have duplicated "1 command" and "model actions" .

Check that each source action appears exactly once across the whole user-turn group, not only
that one block exists. Check the prose turn's own work, later prose turns, and wordless turns.

> don't need "calls" as this is a completely meaningless term in this context.

The grouped header uses action and kind counts; do not repeat a call count there. This is not a
directive to mechanically rename every tool-call concept throughout the product.

> thinking should also be rendered similarly to the "Bash" , "Edit", "Read" etc. tool calls. Should be "Think" and also list the words and time spent thinking.

Match kind icon/name, word preview, timing placement, and row geometry. Do not manufacture an
exact duration from unrelated timestamps. Missing evidence is distinct from zero duration.

> make spacing between these actions consistent. can see inconsistencies when the Think is open.

Measure consecutive rows across source-turn boundaries, with failure badges and open tool/Think
bodies. Per-turn wrappers must not add sporadic gaps to an otherwise continuous action list.

> opening the action should not produce a horizontal rule below it.

Inspect the body border as well as the header and group borders. Preserve the output box itself.

> and the "Think" output belongs in a box.

The output box and its outer inset are separate. Matching the tool body's outer geometry does
not mean leaving the thinking text loose or boxing every collapsed row.

> the bash command box can have the `$` just not the icon.

Keep the `input` label above the box and a single prompt inside it. The kind icon already lives
in the action row.

> have the action list expanded by default. not their actual action contents, just so that the list of actions is showing. then make it so that the "compact mode" toggle collapses these.

Test default visibility, independent output toggles, compact on/off, explicit list reopening,
and a child left open when the parent collapses. Preserve the distinction between list and output.

## Reading width and outline

> the maximum should be near the whole middle container width. near where the "zen" button is.

The maximum depends on available space and reserved control lanes. Check rails open, collapsed,
zen, and window resize. Do not substitute a larger fixed cap.

> let's remove any width snapping on the width handle.

The released width stays where it was chosen. Check pointer interruption and keyboard access too.

> on the <div id="txn-rail-left-body"> want to remove the padding. --sp-4

Make user-turn cards edge-to-edge without stripping their own text inset or other tabs' padding.

> when scrolling to a user turn in the main transcript body, it should also result in the user turns scrolling to that as well. when we start to scroll into a deep transcript, the "user turns" sidebar gets left behind.

Use enough user turns to overflow the actual rail. Verify the current card becomes visible in
both directions while the main reading position and focus remain unchanged.

## Selection, scrolling, and motion

> when I click on a turn, it should also shift the highlighted amber bar on the left to select that turn. when I hover my mouse over a turn, it should change the background effect.

Click selection and hover feedback are distinct. Action blocks do not become selectable turns.

> also match how the reference html page with how the hover background effect fades in and out.

Read the reference's duration and curve. Put the transition on the resting state, not only hover.

> hitting up/down k/j at the top/bottom limits of the page cause the turn selection/scrolling to get stuck, also doesn't work when I press it many times near the limit (even if there are more turns up or down).

Send bursts without waiting for each scroll to finish, overshoot both ends, then reverse.
Reading-line scroll feedback and stale key-handler closures can independently break this.

> expanding and collapsing model actions and their outputs should also expand and collapse smooothly.

Test list, command output, and Think output separately. Keep expensive closed output lazy.

> the ease in and ease out of the actions look really good and smooth. it also flashes content whenever we expand/collapse the aciton though.

Inspect the animation-to-framework commit boundary; do not change accepted easing to mask a
one-frame natural-height flash. Preserve final pixels until hidden state is committed.

> nice. the model actions are animated smoothly now and it doesn't flash content. the title bar still goes through a weird jiggle. maybe because it inserts the timeline row, removes the prior row, and then has to move back up again.

Treat the title/timeline/toolbar/stream as coupled layout. Do not report the title transition as
fixed based only on smooth action disclosure or monotonic height of the title's own wrapper.

## Filters and retained behavior

> On the filter sidebar there should be a filter to hide system turns.

Check actual system rows disappear/reappear, the badge counts them, clear/reset restores them,
and older saved state without the new field leaves them visible. Do not only test checkbox state.

Also recheck host actions/panels, commit markers, search reveal, anchors, initial/return reading
position, alternate tabs, permission-gated exits, and fail-closed share/redaction paths whenever
the changed layout can affect them. UI deprecation is not permission to remove a real flow.
