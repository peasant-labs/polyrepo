---
name: javascript-api-design
description: Use this skill whenever you write or change an API in JavaScript or TypeScript, even when the request does not mention types, enums, closed sets, or branding. Design and review those APIs so every closed set is nominal, typed, and exhaustive instead of stringly. Use for enums, string unions, constants, branded types, wire values, query parameters, page tokens, error models, and schema drift. Also use whenever a prop, URL parameter, wire message, or error path is compared as a raw string, when a TypeScript enum or a bare literal union leaks through a public API, when a consumer needs the Go-style String()/AllX/NewX shape, or when a Go service already defines the set and the client must mirror it without drift. Covers boundary parsers, compile-time exhaustiveness, zero-cost branding, and the performance rules that keep these checks off the render path.
---

# Design JavaScript APIs without stringly values

Use this skill whenever you write or change a JavaScript or TypeScript API: a component prop,
a hook result, a URL contract, a wire adapter, a page parameter, or an error model.

A closed set is a small, known collection of values: a status, a mode, a page size, an error
source, a wire kind. Treat it as a type, not as a string that happens to have a few legal values.

The goal is not ceremony. The goal is that a wrong value is a compile error or a rejected input,
that every member carries its own behavior and labels, and that no consumer writes a raw literal.

This skill mirrors the Go discipline used in this workspace's `internal/defaults`: a named type,
a const set, an ordered `AllX` set, a `NewX`/`parseX` boundary, and a `String()` method. The
JavaScript version keeps those properties without TypeScript enums.

## Terms

- **Nominal type** — a type distinct from every other type with the same structure. TypeScript is
  structural, so nominal safety needs a marker.
- **Brand** — the type-only marker that creates a nominal type. It can be a unique symbol, a
  literal property, or a private class field. The same pattern is called an opaque type, a tagged
  type, or a newtype. The brand is erased at runtime.
- **Branded primitive** — a primitive plus a brand, such as `PageToken`.
- **Closed value** — a frozen singleton object carrying its `wire` value and `label`. It is
  nominal by object identity and its literal `wire`; it needs no brand. Do not call it a branded
  type.
- **Branded class** — a class with a private brand field, so a structural object literal cannot
  stand in for it.

## The rule

One definition site. Zero raw literals downstream.

The only place a member's wire value may be written is the definition that creates the member.
Every consumer uses the value object: its `wire`, its `label`, its `String()`, or its identity.
A review finding is any downstream `case 'value'`, `=== 'value'`, `Record<string, …>` over a
closed set, or `as SomeType` at a boundary.

## Why the obvious shapes fall short

| Shape | Problem |
|---|---|
| `type Mode = 'list' \| 'grid'` | Compile-time only, structural, no label or behavior. Consumers still write `case 'list'` and `=== 'grid'`. A cast at a boundary reopens the set. |
| TypeScript `enum` | Emits a runtime object and cannot cross into a JS/JSX package such as Fairtrade. Numeric enums accept any number; reverse maps leak. It conflicts with erasable-syntax settings. |
| `Record<string, X>` | The key type is `string`, so every misspelled or unknown value compiles. |
| A tag object (`{ source: 'channel' \| 'connection' }`) | The tag is still a raw string. Consumers switch on it. Use separate typed members or branded classes instead. |
| `any`, anonymous envelopes, hand-written wire shapes | Discards the contract at the boundary and cannot drift-test against the schema. |

A derived literal union is acceptable as an internal type. It is not acceptable as the public
prop, URL parameter, wire boundary, or error model. The same applies to a local-only enum or
union: keep it if it never crosses a public, shared, or cross-package boundary, and do not force
the `ClosedValue` shape onto a private helper that needs none of it.

## ClosedValue: the enum without the enum

A branded primitive is still a string at runtime and cannot carry a method. Use a frozen
singleton object that carries the wire value, its label, and the serialization hooks.

```ts
export interface ClosedValue<W extends string | number, L extends string> {
  readonly wire: W
  readonly label: L
  String(): string       // Go-style explicit call
  toString(): string     // String(value), template literals
  toJSON(): W            // persistence, URL state, JSON
}

function closed<W extends string | number, L extends string>(
  wire: W,
  label: L,
): ClosedValue<W, L> {
  const text = String(wire)
  return Object.freeze({
    wire,
    label,
    String: () => text,
    toString: () => text,
    toJSON: () => wire,
  })
}
```

```ts
export const BrowseView = Object.freeze({
  Sessions: closed('sessions', 'sessions'),
  Projects: closed('projects', 'project'),
  Grouped:  closed('grouped',  'helper threads'),
  Flat:     closed('flat',     'every session'),
} as const)

export type BrowseView = (typeof BrowseView)[keyof typeof BrowseView]

/** Go's AllX: the ordered set, not a runtime scan of the object. */
export const ALL_BROWSE_VIEWS = Object.freeze([
  BrowseView.Sessions,
  BrowseView.Projects,
  BrowseView.Grouped,
  BrowseView.Flat,
] as const)
```

The four `closed(...)` calls are the Go const block. Each member forces a wire and a label in
the same statement, so a half-defined member is impossible. Adding a member requires adding its
`ALL_*` entry; a type test catches a forgotten one:

```ts
type MissingBrowseView = Exclude<BrowseView, (typeof ALL_BROWSE_VIEWS)[number]>
const _allBrowseViews: MissingBrowseView extends never ? true : never = true
```

Consumers use `view.label`, `view.wire`, `view.String()`, and identity. They never switch on a
literal:

```tsx
{ALL_BROWSE_VIEWS.map(view => (
  <RadioRow key={view.wire} checked={browse === view} onPick={() => choose(view)}>
    {view.label}
  </RadioRow>
))}
```

If a member needs more metadata, put it on the value, not in a downstream switch:

```ts
closed('sessions', 'sessions', { icon: List, ordered: true })
```

## Parse at the boundary, never cast

The wire value enters the program once, at a URL, a message, a CLI flag, or a host prop. Convert
it there. Every later layer receives the typed value.

```ts
const BROWSE_BY_WIRE: Readonly<Record<string, BrowseView>> = Object.freeze({
  [BrowseView.Sessions.wire]: BrowseView.Sessions,
  [BrowseView.Projects.wire]: BrowseView.Projects,
  [BrowseView.Grouped.wire]:  BrowseView.Grouped,
  [BrowseView.Flat.wire]:     BrowseView.Flat,
})

function isBrowseViewWire(raw: string): raw is BrowseView['wire'] {
  return Object.hasOwn(BROWSE_BY_WIRE, raw)
}

export function parseBrowseView(raw: string | null): BrowseView {
  return raw !== null && isBrowseViewWire(raw)
    ? BROWSE_BY_WIRE[raw]
    : BrowseView.Sessions
}
```

The lookup table is built once. `Object.hasOwn` is the membership check; the predicate carries
the narrowing. Do not use `as BrowseView` here: that is the defect, not the fix.

Choose a declared fallback or fail closed, and say which in the API:

- A URL parameter with a documented default falls back.
- A wire value that cannot be understood fails closed with a typed error. It is never relabeled
  as the first member.
- An unknown value that must be preserved as evidence gets a typed `Unknown` variant carrying
  the original value. Do not silently map it.

For numbers, the same shape: `PageSize` is a closed set with `closed(25, '25')`, and
`parsePageSize` returns the constant or the declared default. Never return a bare number that
happened to parse.

## Object unions and errors: no discriminator strings

When the set is not a scalar but a family of outcomes, use branded classes and separate typed
members. Do not invent `{ source: 'channel' | 'connection' }`.

```ts
declare const channelFaultBrand: unique symbol
declare const connectionFaultBrand: unique symbol

export class ChannelFault {
  private readonly [channelFaultBrand] = true
  private constructor(
    readonly message: string,
    readonly code: ChannelFaultCode,
  ) {}
  static fromServerError(input: ServerErrorFrame): ChannelFault { /* ... */ }
}

export class ConnectionFault {
  private readonly [connectionFaultBrand] = true
  private constructor(readonly message: string) {}
  static fromSocket(input: SocketFailure): ConnectionFault { /* ... */ }
}
```

```ts
interface ChannelResult<T> {
  data: T | undefined
  channelFault: ChannelFault | null      // this channel failed
  connectionFault: ConnectionFault | null // the provider failed
}
```

Consumers test presence, not a tag:

```ts
if (!detail && channelFault) return <TranscriptUnavailable fault={channelFault} />
if (!detail) return <Skeleton />          // connectionFault only adds a note
```

The private brand makes each class nominal. A plain object literal cannot satisfy it. The
fault's code is itself a `ClosedValue` set parsed with `fromWire`; an unknown code becomes a
typed `Unknown` variant.

## Opaque values: brand the primitive

Some values are opaque but not closed sets: tokens, ids, handles. They need a brand, not a
member list.

```ts
declare const pageTokenBrand: unique symbol
export type PageToken = string & { readonly [pageTokenBrand]: true }

export function parsePageToken(raw: string | null): PageToken | null { /* ... */ }
```

Only the parser or the server response produces one. An unrelated string cannot be passed where
a `PageToken` is required.

## Schema ownership and drift

The wire contract belongs to the schema package. The client set is a projection, not a second
definition.

- A set that crosses repositories is owned by the schema. Consumers map wire values to their
  typed values in one module.
- A set that is UI policy (page sizes offered by a table, grouping modes) is owned by the shared
  UI package or the app, once.
- Assert both directions with type tests:
  - every schema value the client promises is present on the client;
  - every client value is a legal schema value.

```ts
type SchemaFilter = LocalSyncPublicationFilter
type ClientFilter = (typeof ALL_PUBLISH_FILTERS)[number]['wire']

type MissingOnClient = Exclude<SchemaFilter, ClientFilter>
const _coversSchema: MissingOnClient extends never ? true : never = true

const _clientIsLegal: readonly SchemaFilter[] = ALL_PUBLISH_FILTERS.map(f => f.wire)
```

A schema rename, addition, or removal becomes a compile error, not a page that silently drops a
value.

## Performance rules

The checks live at the boundary, not in the render loop.

- Freeze the const objects and build lookup tables once at module load. Do not rebuild them per
  render or per row.
- Use a `Set` or a frozen `Record` for O(1) parsing. Do not `Array.find` a closed set on a hot
  path.
- Export `ALL_X` for ordered display. Do not call `Object.values(X)` in a render path.
- Branded types are type-only and erased. The runtime cost is the frozen singleton objects and
  their closures, allocated once.
- Use stable singleton identity for React memo and dependency comparisons.
- Persist with `.toJSON()`. Do not stringify a `ClosedValue` and rely on its object shape.
- Parse once. Internal layers receive typed values and never re-validate.
- Keep page and list payloads bounded by construction. A closed page size is a number, not an
  arbitrary string that reaches SQL.
- State the measurement when claiming performance. Payload bytes, query count, wall time.

## JavaScript-only packages

Fairtrade is JS/JSX. Use JSDoc types, frozen const tables, and the generated `.d.ts` as the
compile-time check. The runtime guard still lives at the boundary.

```js
/** @typedef {'sessions' | 'projects' | 'grouped' | 'flat'} BrowseViewWire */

/** @type {Readonly<Record<BrowseViewWire, string>>} */
export const BROWSE_LABELS = Object.freeze({
  sessions: 'sessions',
  projects: 'project',
  grouped: 'helper threads',
  flat: 'every session',
})
```

The declaration build fails when a member is added without its label. Consumers still receive
the same typed values from the shared table; they do not re-map strings.

## Go parity

| Go | JavaScript / TypeScript |
|---|---|
| `type Mode string` | nominal `Mode` type (closed value) |
| `ModeList Mode = "list"` | `List: closed('list', 'list')` |
| `AllModes` | `ALL_MODES` |
| `NewMode(raw) (Mode, error)` | `parseMode(raw): Mode` |
| `func (m Mode) String() string` | `String()` / `toString()` on the value |
| `IsValid()` | `isMode(raw)` type predicate |
| compile-time exhaustive switch | construction, `ALL_*` coverage test, `assertNever` for type unions |

A `switch` on a typed union with `assertNever` is still correct when the union is made of class
instances. It is not correct when the cases are raw member literals.

## Review checklist

Run this against the changed files, not the whole repository:

- [ ] Every public prop, URL parameter, wire field, and error path uses the nominal type.
- [ ] No downstream `case 'literal'`, `=== 'literal'`, or `Record<string, …>` as the type of a
      closed set. A boundary lookup table keyed by the wire value is allowed.
- [ ] The member literal appears only in the definition module.
- [ ] No `as SomeType` at a boundary; a parser or predicate does the conversion.
- [ ] No `enum` for a public, shared, or cross-package set; no `any`; no anonymous wire envelope.
- [ ] `ALL_*` has a coverage type test.
- [ ] Schema-owned sets have both drift assertions.
- [ ] Unknown values fail closed or have a typed `Unknown`; none are relabeled.
- [ ] Const tables are frozen once; no per-render scans or allocations.
- [ ] `toJSON()` is the persistence path.
- [ ] A mutation test fails when a parser is replaced by a cast, a label is dropped, or a member
      is added without its `ALL_*` entry.

## Definition of done

A closed set is done when:

1. It has one definition site with a wire value and a label for every member.
2. Every consumer uses the value, its label, or its `String()`, never a literal.
3. Inputs are parsed at the boundary; invalid input is rejected or has a declared fallback.
4. Exhaustiveness is checked by construction, a coverage type test, or `assertNever`.
5. Shared sets are schema-owned and drift-tested in both directions.
6. The checks cost nothing in the render path; the only runtime work is the boundary parser and
   the one-time frozen tables.
