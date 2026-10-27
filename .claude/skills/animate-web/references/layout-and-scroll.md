# Coupled layout and scroll intent

## Replacing a title with a pinned timeline

A smooth title collapse is not proof that the replacement is smooth. The title, header padding,
new timeline, turns toolbar, sticky reservation, and scroller can all change geometry at once.

Draw their positions in these states before changing the animation:

```text
expanded       transition              condensed
breadcrumb     breadcrumb              breadcrumb
title/meta     shrinking title/meta    timeline
turns toolbar  timeline + reservation  turns toolbar
stream         moving stream edge      stream
```

This sketch describes the risk, not a required final layout. Inspect the actual flow model.
An absolute pinned row plus a new normal-flow spacer can count its height twice. A delayed
spacer removal can move the content back up after the visually pleasing collapse has finished.

Record frame-by-frame geometry for the header bottom, timeline top/bottom, toolbar top/bottom,
scroller top/height/scrollTop, and a representative content anchor. Track the condensed/pinned
flags alongside geometry. Look for an unexpected direction reversal or a discrete step.

Potential causes to distinguish:

| Observation | Investigate |
|---|---|
| Hidden contents return at full height for one frame | Animation-to-framework presence handoff |
| Title height is monotonic, but stream edge goes down then up | Replacement insertion and flow-space accounting |
| Condensed flag toggles repeatedly at the threshold | Scroll anchoring, overflow guards, changing measurement baselines |
| Reopening starts from an endpoint instead of current size | Cancellation/reversal ownership |
| No-motion mode still jumps twice | Layout sequencing rather than easing |

Choose an explicit choreography appropriate to the product: shared occupied space, a single
container transition, or coordinated reservation of the final layout. Do not conceal the defect
by slowing everything down, fading the entire application, adding delay, or hiding elements from
the recording. Do not change the user's scrolling intent to accommodate the animation.

## Keyboard selection versus reading-line selection

A viewer often selects the turn at a reading line while scrolling, and also lets the user request
a turn explicitly. These are different sources of intent.

**Failure sequence:** a key selects the next turn, smooth scrolling emits an intermediate scroll
event, the reading-line calculation selects the previous turn again, and the next key repeats
the same request. At the bottom, the requested turn cannot align with the reading line at all.
Increasing the number of key presses does not escape the loop.

Maintain a synchronous logical cursor for explicit navigation. An event burst must advance from
the newest requested selection, not the last rendered closure. Protect that request from passive
scroll feedback until manual navigation takes over. Coalesce obsolete scheduled scroll requests;
repeated keys at the logical first/last turn should not restart an identical smooth scroll.

Manual takeover includes wheel/touch scrolling, scrollbar dragging, and supported native page
keys. Respect focused text inputs, editable regions, selects, nested controls, and prevented
events. Reset stale navigation intent on session change or when filtering removes its target.

Test rapid bursts in both directions, extra keys at both ends, reversing direction at an end,
multiple short turns visible at once, filtered/wordless turns, and manual takeover. A test that
waits for each scroll to finish before sending the next key cannot reproduce the burst defect.

## Historical diagnostic example

During the transcript viewer iteration, a frame sample showed header heights descending toward
53px and then briefly returning to 134px before settling. Holding the animation endpoint removed
that particular flash. A subsequent user report still described a title/timeline jiggle, despite
smooth action disclosures. That report requires investigation of the complete replacement layout;
it is not evidence that the first fix or a monotonic title-height test solved the whole header.
