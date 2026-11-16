# How the changelog updates

`CHANGELOG.md` is a generated file owned by the release job. The release PR is
the only writer. An author PR that touches it fails `title-guard` with
`protected-path`; the release PR may change it as a whole file, and nothing
else may. The tag-triggered release notes job extracts the matching section; a
tag without one fails.

## Inputs

The generator (`intent.Generate`) renders from:

- the **pending titles**, newest commit first (the planner's `full` set for
  the release PR, its `before` set for a verify);
- the **base changelog** at the range base (or the epoch when that is newer);
- the **version** and **tag** the planner computed;
- the **date**: the committer date of the newest pending commit.

The section lines run oldest-first, so the generator reverses the pending set
before rendering.

## One line per subject

```text
- <subject> (#<PR>)
```

- `(#PR)` is appended only when the landed subject carried a PR number.
- ` (BREAKING)` is appended when the title declared a break.
- A release commit itself adds no line: the planner leaves the candidate and
  every changelog-changing commit out of the pending set.

Example:

```text
- add the group facet (#11)
- bound the empty state (#12)
```

## Heading style

The generator reads the base file's **latest real section** and follows it:

- Bracketed: `## [v0.2.0] - 2026-11-16` or `## [v0.2.0]`.
- Bare: `## v0.2.0` or `## 0.2.0`.
- Whether the version text carries the tag prefix follows the base.
- Whether a date is written follows the base. A dated base with no date is an
  error, not a guessed date.

An `[Unreleased]` block is skipped when sniffing the style. A base with no
section defaults to the bracketed tag form, dated when a date is given.

## `[Unreleased]`

An existing `[Unreleased]` block keeps its entries. The new version heading
takes the block's place, the block body stays above the generated lines, and
the rest of the file follows:

```markdown
## [v0.2.0] - 2026-11-16

### Added
- the pending item that was under Unreleased

- add the group facet (#11)

## [v0.1.0] - 2026-11-01
...
```

From adoption onward, content PRs stop adding to `[Unreleased]`; the block is
migrated by the first generated section. The tool intentionally keeps the
existing body, so no pending note is lost.

## Repeated release requests

A release title is a request, not content. Two forced cuts in one window would
otherwise render the same sentence twice. The planner and the generator both
collapse release titles with the **same subject**:

- the newest request names the line;
- the level and `!` fold to the strongest request;
- different release subjects keep their own lines, so a content-carrying
  `release[patch]: publish the pending deps bumps` is not swallowed by a cut.

Example: pending `cut a release (#290)` then `cut a release (#287)` renders:

```text
- cut a release (#290)
```

## Staleness

The release PR is compared with the generator (`release-pr --check`). If the
branch tip moved, the content is stale, the check fails with
`release-content-stale`, the PR leaves the queue, and the release job rebuilds
it from the current tip. A stale release commit is never tagged.

The comparison covers the whole changelog text and each protected version
field. A hand edit, a partial write, or a version field that drifted all fail
the same way.

## Tag-time notes

The tag-triggered `release.yml` extracts the section for the tag's version in
the file's heading style (for example `## 0.0.70` when the file uses bare
versions, or `## v0.1.7` when it carries the tag prefix) and uses it for the
GitHub Release notes. If there is no matching section, the notes job fails with
an actionable error. Only the release PR writes that section, so the fix is a
corrected release content forward, not an edit of the released file.

## What not to do

- Do not add a version section or a changelog line by hand.
- Do not edit a released section to fix a duplicate or a typo; a released tag
  and its section are immutable.
- Do not reorder or rewrite the `[Unreleased]` body to influence the generated
  section; the generator preserves it as it is.
- Do not add a changelog entry to a content PR; it fails `title-guard` and the
  release PR is the one writer.
