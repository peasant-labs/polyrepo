<!-- Reference snapshot. Source: https://github.com/peasant-labs/peasant/issues/891
     Title: [P1] Milestone B: show owner, author and producer everywhere
     Body is verbatim as published; edit the issue, not this file. -->

## Problem

Peasant stores three different kinds of provenance and shows only one of them.

- **Pulled transcripts already name their remote people.** `internal/pull/manifest.go` writes `ownerUserId`, `ownerUsername`, and per annotation `authorUserId`, `authorUsername`. Anonymous people arrive as empty strings and the CLI keeps nothing the Village withholds (`internal/pull/owner.go`). `internal/store/pull_store.go` indexes those manifests; the comment on that file is explicit that the rows are a derived index of the on-disk manifests and that pulled rows are foreign and one-way.
- **Local sessions name their producer, not their owner.** `sessions` carries `adapter_version`, `session_origin` and `origin_version` (`internal/store/artifact_mirror.go`). Those fields say which adapter and indexer produced the transcript. They say nothing about who the transcript belongs to.
- **Nothing names a local owner at all**, because Milestone A introduces the first local owner record. Until Milestone A lands there is no owner to show.

The result today: the local gallery, the reader and the collective view list local and pulled
transcripts in one list with no owner line. A reader cannot tell a transcript they recorded from a
transcript a colleague published, and cannot tell either from one they pulled from a collective.

## Scope

Decided scope, relayed by the user. This issue implements it; it does not redesign it.

### Owner on local artifacts

- A locally ingested session carries an owner: the local owner of this data directory, or the Village account that claimed it.
- A locally created annotation carries the same owner.
- Ownership is read from Milestone A's records. This issue does not invent a second ownership store.

### Pulled transcripts stay foreign

- A pulled transcript always shows the remote owner from the pull manifest.
- A pulled annotation always shows its remote author from the pull manifest.
- A claim never makes another person's pulled transcript yours. Never.
- An owner the Village withheld shows as unknown. Do not guess, and do not fall back to the local holder.

### The collective view shows provenance

- The collective view shows whose transcript came from whom: the remote owner for a pulled transcript, the local holder for a local one.
- The collective view never presents a pulled transcript as locally produced.

### Three distinct roles

Keep three roles apart in the data and in every surface:

| Role | Meaning | Source |
|---|---|---|
| **owner** | Whose artifact this is in the local store. | Milestone A's local owner and claim log. |
| **author** | Who wrote a given message or annotation. | The transcript content and the pull manifest's annotation authors. |
| **producer** | Which adapter and indexer produced the transcript. | The existing `adapter_version`, `session_origin`, `origin_version` stamps. No new stamp. |

- The producer role reuses the existing adapter and indexer provenance. Do not add a second stamp, a second version field, or a parallel provenance record.
- A surface that shows a role names the role. Do not merge owner into author, or producer into owner, in a label that reads as one fact.

## Wire state

**No new wire state is expected.** State this check in the proposal, with evidence:

1. `internal/pull/manifest.go` already carries `ownerUserId`, `ownerUsername`, `authorUserId` and `authorUsername` for every pulled transcript and annotation. That covers foreign ownership and foreign authorship.
2. The Village already knows the account that published a transcript. A local artifact pushed to the Village acquires its remote owner from the publishing account, so no served owner field is needed for the push path.
3. The producer stamps already travel with the transcript and are already indexed locally.

If the proposal finds a real gap, it writes the gap down and takes it to peasant-labs/schema as its
own contract change with its own release, before any consumer re-pins. Do not add a field locally
and call it shared.

## Public interfaces

Read-side projections only. No new tables if the check above holds.

```go
// internal/store (proposed shape; names settled in the proposal)
type ArtifactOwner struct {
    Kind        OwnerKind // local | village | unknown | foreign
    LocalOwnerID string   // set for Kind == local
    VillageUserID string  // set for Kind == village or foreign
    Username     string   // display snapshot; empty when the Village withheld it
}
```

```text
peasant village transcripts list --local --json   -> adds owner per row
peasant user show --json                          -> already reports the local owner (Milestone A)
```

- The transcript list keeps its existing top-level array shape. An owner is added per row. Do not reshape the envelope.
- A row that predates ownership, or a pulled row whose owner the Village withheld, reports `unknown`. Never `local` by default.

## Flow

```text
                       +---------------------+
                       |   read a transcript |
                       +----------+----------+
                                  |
                     local row? --+-- pulled row?
                          |               |
                          v               v
              owner = local owner    owner = manifest ownerUserId/Username
              OR the Village account (empty when the Village withheld it)
              that claimed it               |
                          |                 v
                          |        never the local holder, never guessed
                          v                 |
              +-----------+-----------------+
              |
              v
   producer = adapter_version / session_origin / origin_version (unchanged)
   author   = message and annotation authorship (unchanged for pulled; local owner for local records)
```

## Test cases

Named cases, carried as typed fixtures. No inline case tables.

| Case | Asserts |
|---|---|
| `owner-local-session-shows-local-owner` | A locally ingested session shows this data directory's local owner. |
| `owner-claimed-session-shows-village-account` | A session claimed by a Village account shows that account, with its username snapshot. |
| `owner-pulled-shows-manifest-owner` | A pulled transcript shows the manifest's remote owner. |
| `owner-pulled-never-shows-local-holder` | A claim over every local session leaves every pulled row's displayed owner unchanged. |
| `owner-pulled-anonymous-unknown` | A pulled transcript whose manifest owner is empty shows unknown, not the local holder. |
| `owner-pulled-annotation-author` | A pulled annotation shows the manifest's remote author, and never the local holder. |
| `owner-producer-from-existing-stamp` | The producer shown equals the stored adapter and indexer stamps. A second stamp is not required for the case to pass. |
| `owner-three-roles-distinct` | One transcript displays three different roles from three different sources, with three distinct labels. |
| `owner-collective-view-whom` | The collective view labels each transcript with its remote owner, and a local transcript with its local holder. |
| `owner-survives-account-switch` | After signing in as a different Village account, local artifacts keep their claimed owner and do not silently re-attribute. |

## Validation plan

- Focused `go test` on the store projections and the command packages the change touches.
- A mounted web journey for the gallery, the reader and the collective view, in both themes, with a verified served build. Owner, author and producer must each be visible as separate facts.
- The full repository gate runs once for the consolidated change, not per component.

## Blocked by

Milestone A. There is no owner to display until the local owner and claim log exist.

## Blocks

Nothing. Later work in this epic starts after this issue.

## Related

- peasant-labs/polyrepo#37 delivered the account-scoped collective observation store, whose scope is a normalized Village base URL plus a stable Village user UUID. This issue reuses that identity shape; it does not define a second one.
- peasant-labs/peasant#356 is deferred. When its publication ledger lands, ownership transfer events must join that ledger rather than growing a second journal.
