---
name: spec-writing-style
description: Write a spec record — an epic, umbrella issue, milestone issue, proposal or design note — so another developer can pick it up and take it through requirements, design, test cases and implementation without re-interviewing the requester. Covers the three layers (umbrella, milestone, proposal), vocabulary, data shapes, public interfaces, wire-state checks, validation plans, decided-versus-open separation, exclusions, diagrams, reading order and merge dependencies. Use when writing or reviewing any high-level description that must carry enough decided scope to hand off.
---

# Spec writing style

A spec record is the epic, umbrella, milestone, proposal or design note that
carries a decision from a conversation into work. This skill is the style for
writing one.

## Audience and goal

An epic is written for the next person, who is not in this conversation.

They must be able to:

- understand why the work exists and what "done" buys the user;
- see the decided scope without reopening settled questions;
- find every authority that constrains the design;
- produce requirements, a technical proposal, test cases and an implementation
  plan that a reviewer can accept.

The epic makes that work possible and cheap. It does not do that work.

## The three layers

| layer | answers | does not contain |
|---|---|---|
| **Umbrella issue** | Why. The world after. Which milestones, in what order. Decided scope. Exclusions. | Per-milestone design, file paths, task breakdown |
| **Milestone issue** | What this milestone delivers: vocabulary, data shape, public interfaces, wire-state impact, validation plan, acceptance examples. | Implementation steps, worker slices, PR sequencing |
| **Proposal** (later) | Exact interfaces, migration shape, failure modes, named fixture cases, tradeoffs, release gates. | Re-litigating decided scope |

A reader who starts at the umbrella reaches a proposal-ready state without
asking the requester anything.

## Principles

### 1. Every layer answers a different question

An umbrella that describes implementation is too detailed. A milestone that
only says "make ownership work" is too thin. State the question each document
answers, and keep it to that.

### 2. Milestone issues are high-level but concrete

"High-level" means **no implementation plan**, not "no specifics". A milestone
must carry:

- **Vocabulary** — the words the design will use, defined once, so reviewers do
  not invent synonyms.
- **Data shape** — which records exist, what identifies them, what is optional.
  Not DDL.
- **Public interfaces** — commands, routes, events, named by role.
- **Wire-state impact** — whether the shared contract changes, and the evidence
  used to decide that.
- **Validation plan** — which behaviours must be proven, at which level.
- **Acceptance examples** — a few named cases, usually Given/When/Then. The full
  case matrix belongs to the proposal and its fixtures.

### 3. One idea per statement, in declarative voice

Short, flat sentences. One fact each. Present tense.

- Write: "Pulled transcripts are foreign and one-way."
- Not: "It should be noted that, in the current implementation, pulled
  transcripts are generally treated as being foreign in nature, meaning they
  are effectively one-way."

Brevity is not the goal. **Fast comprehension under review** is.

### 4. Show the shape, not the paragraph

A small ASCII diagram beats three paragraphs of relation prose. Use diagrams
for:

- the concept map (systems, repos, data flows);
- the causal chain of a change (contract, then servers, then consumers);
- the difference between two candidate designs.

Keep them structurally simple, inside code fences, and readable in a terminal.

### 5. Separate what is decided from what is open

Three buckets, always distinguishable in the text:

- **Decided** — ratified by the user, quoted or clearly attributed.
- **Proposed** — the author's judgement, offered for review.
- **Open** — a decision the proposal must make.

A reader must never have to guess which bucket a sentence belongs to. Give the
open questions their own section.

### 6. Quote the requester; label the rest as relay

Attribute the requester's words exactly. Mark everything an agent inferred as
relayed or interpreted. This keeps the requirements record auditable and stops
an interpretation from hardening into a quote.

### 7. Scope is closed by explicit exclusion

Every umbrella and milestone ends with an out-of-scope list. Name the tempting
adjacent work, say why it is deferred, and say what would unblock it. Work that
is silently out of scope becomes a review finding.

### 8. Check before you extend

Before proposing new state, walk the workspace ladder:

1. Is the answer already derivable from data both sides hold?
2. Can a consumer compute it from fields it already receives?
3. Does an existing field, route or read already carry it?
4. Only then extend the contract or add a migration.

Record which steps were tried. The reader must see the expensive path was
chosen deliberately.

### 9. Each milestone is one deliverable and one owner

One milestone equals one production code path plus its user-visible surface. Two
independently shippable surfaces are two milestones. Dependencies are native
blocking edges, not prose.

### 10. Sequencing is part of the content

Order milestones so each one is useful on its own. Name what unblocks what. If
an external date drives the order, say so in the document, not only in the
tracker.

### 11. Link authority, not memory

Reference the actual issues, tracker URIs, research documents and code files the
next person must read, with enough context to know why. Never rely on "as
discussed".

### 12. Close with a reading order and a merge-dependency map

Reviewers need the big picture before reviewing one piece. Give them the order
to read in, the order to review in, and what must land before what.

## Body shape

Use these sections unless the subject gives a reason not to.

**Umbrella**

```
Why
Concept map            (ASCII)
Scope                  (one subsection per milestone, child linked)
Vocabulary             (only when a new word is coined)
Guardrails
Wire state
Roadmap after this epic
Out of scope
Reading and review order
Merge dependencies
Related
Decision record        (tracker URIs, research paths)
```

**Milestone**

```
Problem                (grounded in current behaviour)
Scope                  (subsections per behaviour; what changes and what does not)
Open shape questions   (only what the proposal must decide)
Public interfaces
Data shapes
Flow                   (ASCII)
Test cases             (named; Given/When/Then)
Validation plan        (which gate proves which behaviour)
Wire state             (when the contract may be affected)
Blocked by / Blocks
Related
```

## Worked examples

`examples/` holds the snapshot bodies of the reference set. They are the
standard to match.

| file | what it demonstrates |
|---|---|
| `examples/umbrella-local-identity-and-ownership.md` | Umbrella with concept map, two milestones as native sub-issues, vocabulary, guardrails, and an explicit out-of-scope list |
| `examples/milestone-a-local-owner-identity.md` | Backend milestone: data shape, public interfaces and validation without an implementation plan |
| `examples/milestone-b-owner-author-producer.md` | Dependent surface: wire-state check, provenance display, blocked-by edge instead of prose |

Live links: https://github.com/peasant-labs/polyrepo/issues/71,
https://github.com/peasant-labs/peasant/issues/890,
https://github.com/peasant-labs/peasant/issues/891.

When reviewing a new epic, open the worked examples and compare question by
question: what does each reference answer that the new document does not?

## Checklist

- [ ] The umbrella answers why, which milestones, decided scope, and exclusions.
- [ ] Every milestone carries vocabulary, data shape, interfaces, wire impact,
      validation plan and named acceptance examples.
- [ ] Every decided statement is attributed; open questions are in their own
      section.
- [ ] At least one diagram shows the concept map.
- [ ] The out-of-scope list names deferrals and their unblock conditions.
- [ ] The contract-before-consumer path is stated wherever a contract is
      involved.
- [ ] Reading order and merge dependencies are present.
- [ ] No internal task IDs, slice names or phase taxonomy in the body.
- [ ] The tracker board carries the issue, its size, its team, and its iteration
      when the work belongs to a named push.
- [ ] A developer with no prior context could write a proposal from this alone.

## Boundary with epic-composer

`epic-composer` owns the process: group the items, get approval, post the issues,
wire sub-issues and blocked-by edges, label them, place them on the board. It
also carries mechanical posting rules: sentence-level language rules, cross-repo
reference form, `--body-file` quoting, read-back verification.

This skill owns the design record: the layer model, high-level-but-concrete
milestones, decided-versus-open separation, exclusions, diagrams, sequencing,
reading order and merge dependencies.

Where the two overlap — issue body sections and the diagram requirement — this
skill is the fuller statement. When they disagree, follow this skill and update
`epic-composer` so the two do not drift.
