# release-intent title syntax

The title grammar is the whole release decision. The parser is
`intent.ParseTitle`; the PR-time check is `release-intent check-title`; the
queue re-checks the live title in every merge-group build.

## Grammar

```text
title  = type ["(" scopes ")"] ["!"] ["[" level "]"] ": " subject
scopes = scope *("," scope)
scope  = 1*(lowercase letter / digit / "-")
level  = "patch" / "minor" / "major"
landed = title " (#" digits ")"          ; added by the squash merge
```

- `type` is a lowercase word from the closed set below.
- The scope list is optional. Scopes are free-form lowercase words; a scope
  list must not contain spaces. `feat(graph,table)[minor]: ...` is valid.
- A bracket is required, optional, or forbidden by the type's class.
- `subject` is free text after `: `; it becomes the changelog line.
- A landed subject carries the squash PR number as ` (#123)`. The parser strips
  it, the changelog line keeps it.
- The old form `release(vX.Y.Z): ...` is rejected with `old-release-title`.
  Release titles carry a level, never a number.

## Type classes

| Class | Types | Rule |
|---|---|---|
| must-release | `feat`, `fix`, `release` | Always release; the title must carry a bracket. |
| may-release | `refactor`, `perf`, `build`, `revert` | Release only when the title carries a bracket. |
| never-release | `docs`, `test`, `ci`, `chore`, `style` | Never carry a bracket or `!`. |

`release` is an ordinary author-usable type. It means “cut a release of the
work already pending”; the planner still computes the number.

## Levels and version arithmetic

| Level | Effect below 1.0 | Effect from 1.0 |
|---|---|---|
| `patch` | `0.0.69 -> 0.0.70` | `1.2.3 -> 1.2.4` |
| `minor` | `0.0.70 -> 0.1.0` | `1.2.3 -> 1.3.0` |
| `major` | only with `!` (below 1.0 `![minor]` moves the middle number) | `1.2.3 -> 2.0.0` (requires `!`) |

- Below 1.0, a break is written `![minor]`. `![patch]`, `![major]`, and
  `[major]` are rejected.
- From 1.0, a break is written `![major]`; `!` with `[minor]` or `[patch]` is
  rejected, and `[major]` without `!` is rejected.
- A major level never appears without a declared break.
- The planner takes the highest level in the pending set; it never infers a
  level from the type.

The current version is read from the highest final release tag (or, for a spec
surface, from its version constant). The title guard uses the same value when
judging `!`.

## A repo that does not release

`releases: false` in `.github/release-intent.yaml`:

- any bracket or `!` is rejected with `releases-disabled`;
- `feat(scope): subject` is accepted (a must-release type needs no bracket when
  releases are off);
- no version is computed and no release job exists.

This is how a queue-only repo (for example village) uses the title grammar
without a release.

## Examples

| Title | Result |
|---|---|
| `feat(transcript)[minor]: add group facet` | accepted, minor |
| `fix[patch]: typo in the empty state` | accepted, patch |
| `fix(ci): bound the runner wait` | rejected, `missing-bump` (a `fix` needs a bracket) |
| `refactor: split the parser` | accepted, no release |
| `feat(Graph)[minor]: add a facet` | rejected, `malformed` (scopes are lowercase) |
| `docs: explain the queue` | accepted, no release |
| `docs[patch]: explain the queue` | rejected, `bump-on-non-releasing` |
| `feat(graph)![minor]: drop the legacy field` | accepted below 1.0, break |
| `feat(graph)![patch]: drop the legacy field` | rejected, `bang-bump-mismatch` |
| `feat(graph)[major]: break it` | rejected, `bang-bump-mismatch` |
| `release[patch]: publish the pending deps bumps` | accepted, patch; a content-carrying release request |
| `release[patch]: cut a release` | accepted; the forced-cut trigger |
| `release(v0.1.7): ...` | rejected, `old-release-title` |
| `feat: no scope is fine` | rejected, `missing-bump` (the bracket is missing, not the scope) |

## Rejection codes

| Code | Meaning |
|---|---|
| `malformed` | The title does not match the grammar, or the scope list is invalid. |
| `unknown-type` | The type is outside the closed set. |
| `missing-bump` | A must-release type has no bracket. |
| `bump-on-non-releasing` | A never-release type carries a bracket or `!`. |
| `bang-bump-mismatch` | `!` and the level disagree, or a major level has no `!`. |
| `old-release-title` | The old `release(vX.Y.Z)` form. |
| `releases-disabled` | A bracket or `!` in a repo with `releases: false`. |
| `protected-path` | An author PR changed the changelog or a protected version field. |
| `release-content-scope` | A release or cut PR changed a path outside its allowed set. |

`check-title` exits 2 with the code and a six-part message. The workflow policy
reads the code, not the prose.

## Retitling a PR

A title edit needs no push, but a queued PR must be removed from the queue,
retitled, and enqueued again. The merge-group build re-checks the live title, so
a title lowered after its PR-time run is caught before it lands. Do not rely on
the PR-time check alone.
