<!-- Reference snapshot. Source: https://github.com/peasant-labs/peasant/issues/890
     Title: [P1] Milestone A: local owner identity and claim log
     Body is verbatim as published; edit the issue, not this file. -->

## Problem

Peasant keeps a large amount of durable local state and records no owner for any of it.

- `internal/store/migrations.go` ends at `migrationV69` on this tree. No migration creates an owner record. `sessions` carries `adapter_version`, `session_origin` and `origin_version` (see `internal/store/artifact_mirror.go`), which describe the producer, not the owner.
- Village credentials live outside the store, one file per account state, in the config directory (`internal/auth/credentials.go`: `user_id`, `username`, `village_url`, `key_id`, `linked_at`). Signing out, or linking a second Village account, overwrites that file. Nothing survives that records which local artifact was claimed by which account, or when.
- `cmd/peasant/` has no `user` command group. The closest commands are `peasant login` and `peasant logout`, which act on Village state only.
- A pulled transcript is the only local object that already names an owner: `internal/pull/manifest.go` writes `ownerUserId` and `ownerUsername`, and per annotation `authorUserId` and `authorUsername`. `internal/store/pull_store.go` indexes those manifests. Anonymous owners arrive as empty strings, and the CLI keeps nothing the Village withholds (`internal/pull/owner.go`).

So the local half of ownership is missing, and the foreign half already exists and must not be disturbed.

Consequence: on a shared machine or across two Village accounts, a developer cannot answer "whose transcript is this?" or "did I claim this, or did my colleague?".

## Scope

Decided scope, relayed by the user. This issue implements it; it does not redesign it.

### One permanent local owner

- One local owner per peasant data directory. Exactly one, forever, for the life of that directory.
- Created automatically on first use. No Village login is required to have a local owner.
- Signing out never creates a second local owner. Signing in never creates one.
- The local owner is not a Village account, not a username, and not an email address.

### An append-only claim log

- The claim log lives in the account-scoped store, not in an account-neutral table.
- Each entry records: the local owner id, the Village base URL, the Village user UUID, and the time of the claim.
- Each entry also stores the username as a **display snapshot** only.
- A username is never identity. Village user UUIDs are identity. A username can be reused by a different person, and a person can rename themselves.

### Automatic claim while signed in

- While a developer is signed in, new local artifacts are claimed automatically by the signed-in Village account.
- Automatic claiming never rewrites an earlier claim entry.

### The sign-in prompt

On sign-in the developer is offered two actions:

1. Claim only unclaimed artifacts. This is the default.
2. Claim all local sessions.

- "Claim all" adds new claim log entries. Earlier entries are retained unchanged.
- The link is changeable later. A developer can unlink and re-claim from a different Village account.
- Nothing is permanently unreassignable. A later claim never deletes the record of an earlier one.

### Existing installations

- An existing installation starts with nothing claimed.
- It goes through the claim prompt once, including when it is already signed in.
- No ownership history is backfilled. Inventing a claim time that never happened is worse than an empty record.

### CLI

A `user` command group carries this surface. Proposed spelling, confirmed at proposal time:

```text
peasant user show [--json]
peasant user claim [--all] [--json]
```

- `user show` reports the local owner id and the ordered claim log: base URL, Village user UUID, username snapshot, and claim time per entry.
- `user show` needs no Village login and makes no network call.
- `user claim` with no flag claims only unclaimed artifacts. `user claim --all` claims every local session. Both append; neither rewrites history.
- `--json` returns the same facts as the text output. Human progress goes to stderr.

### Web UI

- One claim control: "assign all of this to me".
- One decline control: "not now".
- The claim control stays available in settings after the prompt is declined or completed.

### Storage

- One migration. It adds the owner record and the claim log.
- The migration is one way and becomes immutable once shipped. Review it deliberately.
- The next migration number is selected from live source at implementation time. Do not reserve a number in this issue.

## Open shape questions for the proposal

These are storage and interface decisions, not scope changes. The proposal settles them with evidence.

1. **Where "claimed" is recorded.** Two candidate shapes: a nullable owner column on the artifact tables, updated on claim; or a derived reading of the claim log by artifact ingest time, with explicit per-artifact exceptions. The first makes "claim only unclaimed" a cheap query and a claim a write over many rows. The second keeps the log as the only owner truth and makes every read a join. Pick one and state the consequence for a claim that covers thousands of sessions.
2. **Claim granularity.** Whether a claim covers sessions only, or sessions plus annotations plus bindings. State which artifact classes exist in the store today and which classes the claim covers.
3. **Unlink semantics.** Whether unlinking is a new claim log entry that ends the previous link, or a separate termination record. Either way the earlier entries stay.
4. **Claim time vs ingest time.** How a claim that runs later than an artifact's ingest is ordered against an automatic claim of a newer artifact.

## Public interfaces

```go
// internal/store (proposed shape; names settled in the proposal)
type LocalOwner struct {
    ID        string    // stable, generated once per data directory
    CreatedAt time.Time
}

type ClaimEntry struct {
    ID             string
    LocalOwnerID   string
    VillageBaseURL string    // normalized full base URL
    VillageUserID  string    // stable Village UUID; never the username
    Username       string    // display snapshot only
    ClaimedAt      time.Time
}
```

The Village account identity in a claim entry reuses the account scope that the offline collective
observations already define: normalized full Village base URL plus stable Village user UUID. Do not
define a second scope rule. See peasant-labs/polyrepo#37.

## Data shapes

Sketch only. The proposal finalizes the DDL, the indexes, and the nullability.

```sql
CREATE TABLE local_owner (
    id          TEXT PRIMARY KEY,
    created_at  INTEGER NOT NULL
);

CREATE TABLE owner_claims (
    id                TEXT PRIMARY KEY,
    local_owner_id    TEXT NOT NULL REFERENCES local_owner(id),
    village_base_url  TEXT NOT NULL,
    village_user_id   TEXT NOT NULL,
    username_snapshot TEXT NOT NULL,
    claimed_at        INTEGER NOT NULL
);
CREATE INDEX owner_claims_by_owner ON owner_claims(local_owner_id, claimed_at);
```

Invariants:

- `local_owner` holds at most one row. Enforce it in the schema, not in a caller.
- `owner_claims` is append-only. No update path, no delete path.
- A claim entry never keys on a username. A rename adds no entry. A username reuse adds no entry.

## Flow

```text
first run in a data directory
        |
        v
create local owner  ----------------------------> local_owner row (one, forever)
        |
        v
signed in?  -- no --> artifacts stay unclaimed; owner still exists
        |
       yes
        |
        v
claim prompt: "assign all of this to me" | "not now"
        |
        +--> decline --> nothing written; control stays in settings
        |
        +--> accept  --> append claim entry (unclaimed artifacts) or
                         append claim entry (all sessions, --all)
        |
        v
every new artifact created while signed in --> claimed by the signed-in account
```

## Test cases

Named cases, carried as typed fixtures under `testdata/`. No inline case tables.

| Case | Asserts |
|---|---|
| `owner-created-without-village-login` | A fresh data directory gains exactly one local owner, with no credentials file present. |
| `owner-survives-sign-out` | Sign out, then sign in again. The local owner id is unchanged and no second row appears. |
| `owner-second-row-refused` | A direct insert of a second local owner fails at the schema boundary. |
| `claim-default-unclaimed-only` | With three artifacts, one already claimed, the default claim appends one entry and touches only the two unclaimed artifacts. |
| `claim-all-retains-earlier-entries` | `--all` appends a new entry. The earlier entry bytes are unchanged. |
| `claim-username-snapshot-only` | The Village user renames between two claims. Both entries keep their own username snapshot and share one Village user UUID. |
| `claim-username-reuse-different-uuid` | Two different Village user UUIDs use the same username. They are two distinct accounts in the log. |
| `claim-unlink-and-reclaim-other-account` | Unlink from account one, claim from account two. Both entries remain, in order. |
| `claim-existing-install-prompted-once` | An installation that predates the migration starts unclaimed, is prompted once, and gains no historical entry. |
| `claim-never-touches-pulled-transcripts` | A claim over every local session leaves `pulled_transcripts` and `pulled_annotations` untouched. |
| `migration-forward-only` | The migration applies to a populated pre-migration database, and a downgrade attempt fails loudly. |
| `user-show-no-network` | `peasant user show` succeeds with the Village unreachable and a signed-out CLI. |

## Validation plan

- Focused `go test` on the store, migration and command packages the change touches.
- Migration tests against a fixture database built from the previous schema version, not a hand-written schema.
- Both themes captured for the claim prompt and the settings control, on a mounted production path, before implementation UAT.
- The full repository gate runs once for the consolidated change, not per component.

## Blocked by

Nothing at this time. The requirements record must exist before this issue is planned.

## Blocks

Milestone B. The display work needs an owner to display.
