# Engineering tenets

This page is for anyone who writes code in a peasant-labs repository, by hand or with an agent. It
states how we design and write code: where a value lives, how derived data stays correct, how a
boundary treats input it does not understand, how we think about performance, and how we test.

It does not describe the workflow (branches, reviews, releases, the tracker). Each repository's
`CONTRIBUTING.md` and `AGENTS.md` carry that, and a repository's own guide wins for rules that only
apply inside it.

Each tenet has the rule, the reason, and where to see it in the code. When a tenet and the code
disagree, the code is the bug, unless the tenet is stale. Then fix the tenet in the same change.

## A. One home for every value and every rule

The failure mode this workspace treats as the defect is **drift**: two copies of one fact that
agree today and disagree after the next change. Most tenets in this section prevent drift.

### 1. Name your defaults, give them a type, and say why

A number or a string that controls behavior is a named, typed declaration with a comment that
states its unit and why it has that value. Nobody should have to guess where a limit came from.

- A default that more than one package uses lives in a defaults package. In Peasant that is
  `internal/defaults`. A value that only one package uses stays next to that package, with the
  same shape.
- When one limit depends on another, compute it from the other. Do not type the number twice.
  `RedactScannerMaxLineBytes = MaxJSONLRecordBytes + 1` cannot fall out of step with the record
  limit; a hand-typed copy can.
- A tunable value resolves in one order: an explicit option, then a named environment variable,
  then the default. Environment variable names are typed constants, not string literals at the
  call site.
- A value that mirrors a contract bound names the contract it mirrors, so a reader can check it.

**Where to look:** Peasant `internal/defaults/` (`pipeline.go`, `env.go`, `retained_unknown.go`),
`internal/ingest/parallel.go` (the staging arena), `internal/store/store.go` (the pool size).

### 2. A closed set is a type, not a convention

When a value can only be one of a known set (a harness, an origin, a license, a redaction
category, a section id), the code makes that impossible to get wrong.

- Go: a named type, one constant per member, an `All` list in canonical order, and a constructor
  or `Validate` that refuses anything else. It never substitutes a default for an unknown value.
- The zero value means "unknown" or "not proven". It never means "allowed".
- A database `CHECK` that lists the same members is tested against the `All` list, so widening
  the type without a migration fails a test.
- JavaScript and TypeScript: nominal closed-value constants, parsed once at the boundary. No
  public `enum`, no comparison against a raw string literal, no cast at the boundary. The
  `javascript-api-design` skill in `.claude/skills/` has the full rules.

**Why:** a stringly typed set has no single place that lists its members, so every consumer keeps
its own idea of the list. A typed set has one.

**Where to look:** Peasant `internal/sessionorigin/origin.go` and the matching `CHECK` in the
store migration; schema `AllLicenses` and the license tables that are derived from it; redact
`AllCategories()` and `Category.String()`. Peasant's `ast-grep/no-raw-newtype-cast.yml` refuses a
raw cast to its identifier types.

### 3. One function owns each decision

A decision that has consequences (which sessions are in scope, which rules bind a repository,
which categories are redacted, how a wire payload becomes a view model) is made in exactly one
function. Everything else calls that function or receives its result.

**Why this matters more than it looks:**

- **Two copies drift.** A copy in the web client and the original in the server agree on the day
  the copy is written. The next change updates one of them. Then the list the user sees and the
  action the server takes disagree, and nothing fails until a person notices.
- **Consent and privacy depend on it.** Peasant shows a developer what will be published and then
  publishes it. If the preview and the publish path decide separately, the preview can show one
  thing while the server does another. Consent to something you were not shown is not consent.
  The same is true of redaction labels and of who can read a transcript.
- **One owner means one test corpus.** The fixtures that prove the rule run against the one
  function. A copy needs its own fixtures, and nobody keeps two corpora in step.
- **A change is one diff.** When the owner changes, every caller gets the change, and a version
  bump (tenet 6) can mark the old results stale.

**What a consumer may do instead:** compare fields it already receives, or restate the server's
decision in user-facing words that decide nothing. What it must not do is re-derive the rule and
then act on the result.

**Signs that you are writing a copy:** a TypeScript function that mirrors a Go function; a second
list of the members of a closed set; a `switch` over the same set in two packages; a "temporary"
client-side filter that repeats a server filter.

**What to do instead:** call the owner, expose the owner's result in an existing field or route,
or, if two repositories genuinely need the rule, move it into the shared contract (tenet 4).

**Where to look:** Peasant `ingest.SelectionMatcher` (ingest, push, and prune all call it),
`autopublish.Decide`, and the session detail path `store.ListEntries` →
`transcript.EntriesToTurns` → `transcript.SessionToDetail`; redact `Category.String()` for every
rendered label; fairtrade `adaptTranscript`, the one place that parses the wire format for both
web apps. A thin wrapper that forwards to the owner is fine; a second algorithm is not.

### 4. A concept two repositories share belongs to the contract

If two repositories must agree on something, the shared `schema` module defines it, and both
consume it. Village serves and enforces the same embedded bytes it validates against, so what it
documents and what it enforces cannot differ. A consumer adapts to the contract; it does not keep
its own version of it.

Before you extend the contract or add a column, try these in order and take the first that works:

1. Is the answer already derivable from data both sides hold?
2. Can the consumer compute it by comparing fields it already receives?
3. Does an existing field, route, or read already carry it?
4. Only then extend the contract or add a migration.

### 5. Do not store what a reader can derive

Never add a field whose value a reader can compute from fields it already has: a copy of another
value in the same response, a status that the presence of an object already implies, an echo of
the request, or a copy of what an embedded payload carries. Two fields that must agree will
eventually disagree, and then every reader needs a rule for the mismatch. State the derivation in
the doc comment instead.

This applies to wire fields, CLI JSON output, and database columns alike. An index adds no
meaning and is often the right answer. A column adds state, and state has to be kept true.

If a derivation is genuinely too slow or too complex, storing the result can be the better
tradeoff. Say so in the issue or pull request, with the cost of deriving, the drift risk of
storing, and what keeps the stored value true (a version, a backfill, a test).

### 6. Write the declaration by hand; generate the rest

When several artifacts follow from one declaration, the declaration is the only thing you edit.
The rest is generated and checked for freshness, so a regeneration produces no diff.

Examples: Peasant's record-kind registry and its docs come from the `*_vocabulary.go` files; the
schema's OpenAPI documents and TypeScript types come from the Go types; fairtrade's `tokens.json`,
`components.json`, and `DESIGN.md` frontmatter come from the token blocks in `src/index.css`;
Village's query code comes from its SQL through `sqlc`.

Never hand-edit generated output, and never hand-merge it in a conflict. Merge the source and run
the generator again.

## B. Derived data says what produced it

### 7. Stamp every derived result with its producer and version

When code turns input into stored output (a parser into session rows, a classifier into a
verdict, a rule set into redactions, a checker into a response), the stored output records which
code produced it and at which version.

Peasant stamps each stored session with the adapter version, the indexer (parser) version, the
stored format version, the origin rule version, the metadata schema version, and hashes of the
input it read. A managed generation is an immutable row with its own versions and digests. The
same idea appears as redact's `RuleSetVersion`, scry's `ScryVersion`, and the schema's spec
versions.

A missing stamp means "unknown". It never means "current".

**Why:** without a stamp you cannot answer "is this row still right?" except by recomputing
everything. With a stamp, the answer is a comparison.

### 8. Change the behavior, bump the version, recompute only what is stale

When you change what a producer outputs, bump that producer's version in its one registry.
Maintenance then selects the stored rows whose stamp is older than the target and recomputes only
those.

- In Peasant, per-harness versions live in `internal/ingest/harvester_versions.go`. Stale rows
  are selected with a strict "stored < target" comparison. Record the bump and its reason in
  `docs/indexer-version-history.md`.
- Bump the format version only when the stored representation changes, not for a parser fix.
- Do not add a one-off backfill flag. The version comparison is the backfill.
- If a stored row was produced by a newer version than the running build, refuse to overwrite it.
  An older build must not quietly downgrade newer data.

### 9. History is append-only

Shipped migrations, retired spec versions, managed generation rows, the governance audit log, and
release tags are never rewritten. To change one, add a new one. Tests pin the old ones: Peasant
pins each migration with a unique needle, the schema pins retired specs by hash, and a database
trigger refuses updates to generation rows.

## C. Boundaries keep what they do not understand, and never decide with it

### 10. Record unknown input as unknown; never coerce it, drop it, or trust it

At every boundary where outside data comes in (a provider's session file, a wire payload, a
config file, a CLI flag), parse once, into the typed values of tenet 2.

- **Do not coerce.** An unrecognized category, origin, or harness is never mapped to the nearest
  known value. A renamed legacy value gets an error that names its replacement, not a silent
  mapping.
- **Do not drop silently.** When a producer meets a record it cannot interpret, it keeps the
  record as explicitly unknown evidence and marks the result as partial. The schema's
  `RetainedUnknownRecord` with `diagnostics.partial = true` is the shape. A record that is too
  large becomes a placeholder that says what was omitted; it never disappears and it never fails
  the whole session.
- **Do not trust.** Unknown evidence never grants anything: it does not satisfy a gate, widen
  access, or count as proof. An evidence type's zero value is "not proven".
- **Refuse what you cannot represent safely,** such as data from a newer producer version or an
  unknown redaction category at a trust boundary, with an error that says what failed, why, where,
  what it means for the caller, and how to fix it.
- **Promote deliberately.** Something unknown becomes known through its owner: a new harness is
  declared in `bestiary` and the schema, then gets an adapter, a data fixture (tenet 14), and a
  version. Observing a tool's storage layout is allowed before that and records shape only, never
  content.

Where an output is itself a contract, make it deterministic: the same input bytes give the same
output bytes, with no clock, randomness, or map order in the result. Scry is the strict example.

## D. Performance is designed in

### 11. Bound everything

Every buffer, query, batch, and transaction has a stated bound, and the bound is a named default
(tenet 1). Lists are paged. A single oversized record is omitted with a placeholder rather than
read without limit. No N+1 queries.

### 12. Parallel CPU, one serial writer, and skip unchanged work

- Parse, hash, encode, and classify in bounded worker pools. Send every SQLite write through one
  serial lane in bounded, batched transactions, with a savepoint per session so one failure does
  not abort the batch.
- Skip work whose result would not change: compare the stamp (tenet 8) or the projection before
  you redo it, and make staging idempotent so a retry is free.
- Take multiple locks in a fixed order.

### 13. Measure before you decide

- The user's live store is read-only for development. Measure on a sandbox copy.
- Record the date, the revision, and the exact command with every number. Label an estimate as an
  estimate.
- A budget has three parts: how it was derived, a setting to change it, and a check that tests
  the invariant, not the constant.

Peasant's `.claude/skills/design-performance/SKILL.md` has the full rules and the measurements
behind them.

## E. Tests and fixtures

### 14. Keep two kinds of fixtures, and do not let one replace the other

**Case fixtures** are YAML tables of inputs and expected results. Use them for combinatorial and
permutation cases. Load them with `//go:embed` (or the language's equivalent), and protect them
with a manifest of required case names, not a count: a count changes on every addition, a name
list fails only when a case actually disappears. For closed or security-relevant sets, assert the
exact membership. The schema's `testcase` package is the shared loader.

**Data fixtures** are synthetic files in the exact shape a provider writes: a Claude Code
project directory, a Codex rollout, an OpenCode database, a Cursor transcript. Each harness has a
directory of them with an index file that declares the sessions and the facts to check. They are
hand-authored or synthesized, never copied from a real person's machine, and a no-secrets gate
scans them.

**Why both:** a case fixture proves that a function maps an input to an output. A data fixture
proves that the real adapter, reading a real directory layout, still finds the sessions, parses
the records, links parents and children, and produces the expected rows. Providers change their
formats without notice. A synthetic copy of the new shape, committed next to the old ones, is how
we know the parser still works, and it is the corpus the parser-version guard replays to decide
whether a change needs a version bump (tenet 8).

**The rule:** every registered harness has a data-fixture directory. When a parser change is
caused by a new or changed provider shape, add a synthetic file of that shape to the harness's
data fixtures, not only a string inside a YAML case.

### 15. Test the production path

- Use an integration test first for anything that involves I/O, state, or more than one
  component.
- Mock dependencies, never the system under test. Import the code users run; do not add a
  test-only export.
- Inject the dependencies a test needs to replace (the filesystem, the store, the clock, the
  network).
- Wait on a signal or a deadline, never a sleep.
- For user interfaces, test the mounted application path in both themes, not an isolated story.
- Before you build an elaborate harness, answer the test promotion checklist in the workspace
  guide. A test that is bigger than the invariant it protects is a cost, not an asset.

## F. User interface

### 16. Every visual value is a token

Fairtrade defines every color, space, size, and motion value as a CSS custom property in the
`:root` (dark) and `[data-theme="light"]` blocks of `src/index.css`. Semantic tokens point at
primitive ones, so a new style is defined from existing tokens wherever possible. Components emit
class names and style themselves with `var(--…)` only. A lint rejects raw colors and spacing
outside the token blocks, and a contrast check runs both themes against WCAG AA.

To add a style, add a token. Never put a literal value in a component.

### 17. Fairtrade owns rendering; apps adapt

Both web apps render transcripts through fairtrade's components and its one adapter,
`adaptTranscript`. An app composes and configures them; it does not re-implement or fork them. A
new visual pattern lands in fairtrade before an app uses it.

Syntax highlighting is structured only: use `codeToHast` or `codeToTokens` and render through
React, so transcript text stays escaped. Never `codeToHtml`, and never `dangerouslySetInnerHTML`
for highlighted code.
