# Local-first identity and ownership

Status: design record for `peasant-labs/polyrepo#71`, with child issues
`peasant-labs/peasant#890` (Milestone A) and `peasant-labs/peasant#891`
(Milestone B). The rulings below are settled and bind
`peasant-labs/peasant#951` (store, CLI and migration V82) and
`peasant-labs/schema#219` (Local API contract).

## Requester rulings (2026-11-18)

These rulings supersede earlier rulings where they differ. They are applied in
this record and in `peasant-labs/polyrepo#71`; `peasant-labs/schema#219` and
`peasant-labs/peasant#951` are checked against them.

| Topic | Requester's ruling |
|---|---|
| Sessions first stored while active | "harvest/claiming should properly claim active sessions though." |
| A claim that finds nothing | "'Explicit claims append, so an explicit claim that claimed nothing still records its decision.' should be the correct contract." |
| Account switch and back | "yes: strict reuse. will be the only way we actually have a replayable, durable event stream in the 'durable objects' sense." |
| Claim-log order | "newest first, with an 'older' cursor. want this to be performant too: similar to optimizations we made to improve migration performance." |
| Unlink | "yeah, unlink can be left for later. accept narrowing." |
| Notice for signed-in installs | "This notice is okay. web and hook notices or UIs can come later." |

The derived rulings follow in decisions 1-7: "first stored" is defined by
evidence (decision 4), reuse is strict (decision 4), the log is newest first and
read N+1 (decision 4 and Storage), the owner file carries integer milliseconds
and refuses a mismatch (decision 7), and a later unlink is an additive
termination table (decision 3).

## Authority and scope

Authority: `peasant-labs/polyrepo#71` and its child issues
`peasant-labs/peasant#890` and `peasant-labs/peasant#891`.

This record settles the four open shape questions from peasant#890 before a
forward-only migration ships:

1. Where "claimed" is recorded.
2. Which artifacts a claim covers.
3. What unlinking means.
4. How a late claim is ordered against an automatic one.

It also rules whether the web surfaces need new wire state. They do: the Local
API needs owner, claim and prompt state. No Village route, publish type, or
pulled-manifest field changes.

Where a child issue and this record differ, this record's ruling is the
deliberate reading and the child issue is amended to match. A later claim is not
permission to keep the older text.

## Rulings at a glance

| Question | Ruling | Where |
|---|---|---|
| Which artifacts may an automatic claim cover? | Only artifacts first stored by this harvest: a session with no database row and no saved pair before the run, or a newly created annotation. Sessions first stored while active are included. Forced or web re-processing, `harvest index --all` and rebuilds wait for an explicit claim. | Decision 4; named cases |
| When does an automatic claim reuse an entry? | Only when the newest entry of the log, by insertion order, is this account's `automatic` entry. Otherwise it appends. Explicit claims always append. | Decision 4 |
| How is the claim log read? | Newest first (`claimed_at DESC, rowid DESC`), N+1 rows to detect older entries, at most 100 returned, with an older cursor. | Decision 4; Web |
| What does unlinking mean? | This step ships no unlink. Reassignment is all-or-nothing; the log proves which accounts claimed and when, not what each entry covered. A later unlink is an additive termination table. | Decision 3 |
| Where does owner permanence live? | In `local-owner.json` beside the store, created or adopted on the first writable open of a current-schema store and at the end of an upgrade; never on a read-only open. Adopted on rebuild. The claim log does not survive a rebuild. | Decision 7 |
| What does the web need? | Three local routes with fixed controls, request bodies, prompt states, entry/result fields, error statuses, a newest-first 100-entry read bound with an older cursor, and strict automatic-entry reuse. | Web |
| What does V82 do to the parent-state trigger? | Drops and recreates `sessions_parent_state_au` with `owner_claim_id`, at a per-row cost. | Storage |
| What keys the prompt decision? | Local owner id plus the normalized account scope. | Decision 6 |
| What is the authority and the named-case set? | `peasant-labs/polyrepo#71` and its child issues; the named-case list and its required proofs. | Authority; named cases |
| What is the merge order? | This record settles first and is safe alone; the two implementation PRs wait and stay draft. | Merge dependencies |

## End state

One `peasant` data directory holds one permanent local owner. Local sessions and
annotations carry an owner that is either that local owner or the Village
account that claimed them. Claims are append-only. Pulled transcripts and pulled
annotations remain foreign, one way and non-republishable.

Every surface keeps three roles distinct:

| role | meaning | source |
|---|---|---|
| owner | whose artifact this is in the local store | this record's local owner and claim log; the pull manifest for foreign rows |
| author | who wrote a message or annotation | transcript content and the pull manifest's annotation authors |
| producer | which adapter and indexer produced it | existing `adapter_version`, `session_origin`, `origin_version`, `index_version` stamps |

## Decisions

### 1. Where "claimed" is recorded

A current pointer plus an append-only log:

- `sessions.owner_claim_id` and `annotations.owner_claim_id` are nullable text
  columns. `NULL` means unclaimed.
- `owner_claims` is the append-only log. A claim entry is one link between the
  local owner and a Village account at a point in time. An explicit claim always
  appends one entry, even when it moves nothing, and then sets the current
  pointer on the artifacts it covers. An automatic claim reuses the newest entry
  only when that entry is this account's `automatic` entry; otherwise it appends
  one (decision 4).
- The pointer has no foreign key. `PruneSessions` must keep working, and a
  claim entry must survive the artifact it covered. The log is the history; the
  pointer is the current projection.

Consequence: "claim only unclaimed" is one indexed `UPDATE ... WHERE
owner_claim_id IS NULL` per artifact table. A claim over thousands of sessions
and annotations is a bounded write transaction, not a full table rewrite. The
history remains complete after artifacts are pruned because `owner_claims` has
no artifact foreign key. Re-claiming overwrites only the current pointer; it
never rewrites an earlier log entry.

Both claim paths append or reuse the claim entry first, then update pointers in
bounded transactions so an interrupted claim can resume without appending a
second entry for the same explicit action.

The log proves which accounts claimed and when. It does not prove which
artifacts an earlier claim covered once the pointers move. That limit is
deliberate in this step; see decision 3.

### 2. Claim granularity

A claim covers local sessions and local annotations.

- Sessions: every row in `sessions`.
- Annotations: every row in `annotations`, including classifier output. The
  owner of an annotation is the owner of the local store, not the classifier
  persona. `annotator_id` remains the author/producer-side label and is not
  reused as owner.
- Newly created human annotations from `annotate create`, `annotate import`,
  and the web annotation handler are claimed when they are stored, using the
  same strict reuse rule as sessions: reuse only the newest `automatic` entry
  for this account, otherwise append. An annotation created on an updated or
  reindexed session is still a new artifact; the session's own non-new status
  does not suppress the annotation claim.
- Bindings and associations (`session_commit_associations`,
  `session_generation_associations`, and target rows) are not separate artifact
  classes. They inherit their session's owner.
- Pulled rows (`pulled_transcripts`, `pulled_annotations`) are never claimed
  and never written by claim code.

### 3. No unlink; reassignment is all-or-nothing

This step ships no unlink. A reassignment is all-or-nothing and cannot be
undone per artifact. The log proves which accounts claimed and when, not what
each claim covered.

- Milestone A has no separate unlink record, no "unlinked" claim state, and no
  per-artifact undo.
- Signing out does not remove a claim. A claim is a completed action and stays
  as historical evidence.
- A later claim from another Village account appends a new entry and moves the
  current pointer on every local row in scope. Earlier entries remain unchanged;
  the rows they covered are no longer individually identifiable from the log.
- `claim --all` and the web claim-all control are explicit reassignments. They
  are documented and labelled as such. They do not delete history.
- Recovering a single person's rows after a shared-machine reassignment requires
  a later additive coverage table or termination record. Neither is in V82.
- Lost or revoked Village access grants nothing. The claim remains evidence
  only.

This narrows peasant#890's "can unlink and re-claim" to "can re-claim from a
different account, all-or-nothing". The requester accepted the narrowing on
2026-11-18: "yeah, unlink can be left for later. accept narrowing."

A later unlink is an additive termination table, not a new `source` value. The
`source` CHECK constraint cannot change without rebuilding `owner_claims`, and a
shipped migration is immutable. An unlink record therefore references the claim
entry it terminates and leaves the log and its CHECK constraint untouched.

### 4. Claim time vs ingest time; automatic claims are first-stored-only

The current pointer is authoritative for ownership. The log is ordered newest
first: `claimed_at DESC, rowid DESC`. `claimed_at` is a millisecond wall-clock
time and each entry has a stable id.

- A manual claim records the wall-clock claim time.
- An automatic claim covers only artifacts this harvest stored for the first
  time. "First stored" means the session had no `sessions` database row and no
  saved pair under `peasant-sync/` before the run, whatever status the pipeline
  reports. A session first stored while still active is included and is claimed
  on that first run; the requester ruled on 2026-11-18: "harvest/claiming should
  properly claim active sessions though." Newly created human annotations from
  `annotate create`, `annotate import`, and the web annotation handler are
  claimed when they are stored.
- The write site reads a `FirstStored` flag on the pipeline result. It must not
  infer "first stored" from `DiffNew`, `DiffActive` or `DiffUpdated`: `--force`
  reports a stored session as `DiffNew`, the web one-session ingest sets
  `Force = true`, and a rebuild from saved copies reports stored sessions as
  `DiffUpdated`.
- An automatic claim therefore excludes all of:
  - `peasant harvest --force` re-processing a stored session;
  - the web one-session ingest of a stored session;
  - `peasant harvest index --all` over stored sessions;
  - a database rebuild from saved pairs.

  Those rows stay unclaimed until the sign-in prompt or an explicit
  `peasant user claim`.
- Strict reuse: an automatic claim reuses a claim entry only when the newest
  entry of the whole log for this local owner, by insertion order, is this
  account's `automatic` entry. Otherwise it appends a new `automatic` entry.
  Explicit claims (`manual` and `sign_in_prompt`) always append, including when
  they move nothing and on an empty store. A claim that finds nothing still
  records its decision and returns its `claimId`. The requester ruled on
  2026-11-18: "yes: strict reuse. will be the only way we actually have a
  replayable, durable event stream in the 'durable objects' sense."
- Replaying the log in insertion order shows, at every point, which account
  receives new artifacts. Reuse is what makes that replay durable and compact:
  consecutive harvests by one account add no entries, while every takeover or
  explicit claim adds one.
- An automatic claim sets ownership only where the pointer is `NULL`. It never
  moves a row that already belongs to another account.
- No historical claim times are invented for existing installations. Existing
  rows start with `owner_claim_id = NULL`.
- An artifact created before a claim but never claimed is covered by the next
  explicit claim, because "unclaimed" is the pointer being `NULL`, not an
  ingest-time comparison. There is no automatic backfill.
- A declined prompt is not a claim. A run after a decline may still claim only
  the artifacts it stored for the first time; it may not claim the rows the
  person declined.

#### Claim-log order and paging

The requester ruled on 2026-11-18: "newest first, with an 'older' cursor. want
this to be performant too: similar to optimizations we made to improve migration
performance."

- The order is newest first: `claimed_at DESC, rowid DESC`.
- The page read is
  `WHERE local_owner_id = ? [AND (claimed_at, rowid) < (?, ?)]
  ORDER BY claimed_at DESC, rowid DESC LIMIT 101`. It returns at most 100
  entries.
- A cursor (`before` on the wire, `nextBefore` in a status) resolves to its
  row's `(claimed_at, rowid)` pair.
- `nextBefore` is the last returned entry's id, present exactly when a 101st
  row exists. It is absent when fewer than 100 entries are returned.
- `totalClaims` counts the whole log and decides nothing; in particular it does
  not decide whether a cursor is present.
- The page read uses `owner_claims(local_owner_id, claimed_at)`. The reuse
  lookup uses `owner_claims(local_owner_id, village_url, user_id, claimed_at)`.
  Neither may take a temporary B-tree sort; a query-plan assertion runs both and
  fails on `USE TEMP B-TREE`.

### 5. Account scope

A claim entry reuses the account scope from `polyrepo#37`:
`CollectiveObservationScope` is a normalized, full Village base URL plus a
stable Village user UUID. The username is a display snapshot only.

The claim row stores `village_url` and `user_id` using the same names and
grammar as `collective_observation_scopes`, and references that scope with a
composite foreign key. The scope row is created idempotently when a claim is
written; claim code does not bump the collective-observation invocation
sequence.

`source` is a typed closed set: `manual`, `sign_in_prompt`, or `automatic`. Parse
it at the boundary, reject an unknown value before any write, and assert exact
set membership in a test.

### 6. Prompt state and decline

The server computes a typed prompt state:

| state | meaning |
|---|---|
| `not_applicable` | no Village account is selected. |
| `due` | signed in, with no decision for this local owner plus account scope. |
| `declined` | the person chose "not now". |
| `completed` | a claim decision was completed. |

`LocalOwnerClaimPrompt` carries `state`, the account scope when signed in, and
`decidedAt` when settled. The client renders the state; it does not re-derive
whether the prompt is due.

A decline is not a claim. It records only that the prompt was dismissed for one
local owner plus account scope, so the product does not nag. It lives in runtime
state (`<state-dir>/peasant/claim-prompt.json`). The state key is the local
owner id plus the normalized Village base URL plus the Village user UUID, so two
data directories that share a state directory do not share an answer. A decline
is never written to `owner_claims`.

A claim failure leaves the prompt decidable so `peasant user claim` can retry.

An existing installation that is already signed in is prompted once. On an
interactive `harvest` or `open`, when signed in, with no decision for the scope
and unclaimed rows, print a one-time stderr notice with the unclaimed count and
the `peasant user claim` command, and record that the notice was shown. The
notice does not interrupt the command. The requester accepted this reading on
2026-11-18: "This notice is okay. web and hook notices or UIs can come later."
Web-only and hook-only installs get no notice until the web prompt ships.

### 7. Owner permanence

The local owner id and creation time are written once to
`<data-dir>/local-owner.json`, beside the SQLite store (`<data-dir>/peasant.db`),
in this format:

```json
{
  "id": "lo_<uuid>",
  "createdAt": 1794989016147
}
```

`createdAt` is an integer Unix millisecond, matching what the store reads and
writes. The file is created with owner-only permissions and is never stored
inside the database.

The owner is created or adopted on the first writable open of a current-schema
store, and at the end of an explicit upgrade. Opening never migrates on its own.
A read-only open (`OpenReadOnly`) and `WithImmutableReadOnly` never create the
owner and never write the file; a read-only open of a store with no owner
reports no owner rather than minting one. `user show` only reads.

- When the file exists and the database has no owner, the store adopts the file.
- When the database names an owner and the file is missing, the store writes the
  file from the database atomically; it does not mint a second owner.
- When both exist and the ids differ, the store refuses to open with an
  actionable error naming both owner ids and the file path. It does not keep one
  side silently, because the next rebuild would then switch owners.

A database rebuild that deletes `peasant.db` keeps `local-owner.json`. The new
store adopts the same id and `createdAt`; the creation time is the original, not
the rebuild time. The claim log does not survive a database rebuild: a rebuilt
store starts unclaimed, and the first claim after the rebuild appends the first
entry (automatic only for an artifact first stored by that run, otherwise
explicit). The peasant recovery hints that tell people to delete the database
must say both: the owner id file is retained, and the claim log is not.

A corrupt or unreadable `local-owner.json` is an error that names the path; the
store does not silently mint a second owner. Deleting both the file and the
store is the documented way to start a new owner.

Tests: `owner-created-after-upgrade-from-v81`, `read-only-open-creates-no-owner`,
`owner-file-mismatch-refused`.

## Storage

Migration V82 is the next slot in the live source. `develop` already ships
V79–V81, so V82 is selected and the index change is folded in before it ships.
The number is always selected from live source at implementation time. It adds:

```sql
CREATE TABLE local_owner (
    id          TEXT PRIMARY KEY CHECK (length(id) BETWEEN 1 AND 64),
    singleton   INTEGER NOT NULL DEFAULT 1 CHECK (singleton = 1) UNIQUE,
    created_at  INTEGER NOT NULL CHECK (created_at > 0)
) STRICT;

CREATE TABLE owner_claims (
    id                TEXT PRIMARY KEY CHECK (length(id) BETWEEN 1 AND 64),
    local_owner_id    TEXT NOT NULL REFERENCES local_owner(id),
    village_url       TEXT NOT NULL,
    user_id           TEXT NOT NULL,
    username_snapshot TEXT NOT NULL,
    claimed_at        INTEGER NOT NULL CHECK (claimed_at > 0),
    source            TEXT NOT NULL CHECK (source IN ('manual','sign_in_prompt','automatic')),
    FOREIGN KEY (village_url, user_id)
        REFERENCES collective_observation_scopes(village_url, user_id)
) STRICT;

CREATE TRIGGER owner_claims_no_update
BEFORE UPDATE ON owner_claims BEGIN
    SELECT RAISE(ABORT, 'owner_claims is append-only; append a new claim');
END;

CREATE TRIGGER owner_claims_no_delete
BEFORE DELETE ON owner_claims BEGIN
    SELECT RAISE(ABORT, 'owner_claims is append-only; claims are retained');
END;

CREATE TRIGGER owner_claims_no_insert_or_replace
BEFORE INSERT ON owner_claims
WHEN EXISTS (SELECT 1 FROM owner_claims WHERE id = NEW.id)
BEGIN
    SELECT RAISE(ABORT, 'owner_claims is append-only; a claim id is never replaced');
END;

CREATE TRIGGER local_owner_no_second_row
BEFORE INSERT ON local_owner
WHEN EXISTS (SELECT 1 FROM local_owner)
BEGIN
    SELECT RAISE(ABORT, 'local_owner holds exactly one row; it is permanent');
END;

CREATE TRIGGER local_owner_no_update
BEFORE UPDATE ON local_owner BEGIN
    SELECT RAISE(ABORT, 'local_owner is permanent; never update the owner');
END;

CREATE TRIGGER local_owner_no_delete
BEFORE DELETE ON local_owner BEGIN
    SELECT RAISE(ABORT, 'local_owner is permanent; never delete the owner');
END;

CREATE INDEX idx_owner_claims_owner_order
    ON owner_claims(local_owner_id, claimed_at);

CREATE INDEX idx_owner_claims_scope_order
    ON owner_claims(local_owner_id, village_url, user_id, claimed_at);

ALTER TABLE sessions ADD COLUMN owner_claim_id TEXT;
ALTER TABLE annotations ADD COLUMN owner_claim_id TEXT;

CREATE INDEX idx_sessions_owner_claim ON sessions(owner_claim_id);
CREATE INDEX idx_annotations_owner_claim ON annotations(owner_claim_id);
```

The owner-order index leaves the `rowid` tie-break implicit:
`ORDER BY claimed_at DESC, rowid DESC` is newest-first insertion order, not
random-id order. The page read uses that index; the strict-reuse lookup uses the
scope-order index. Both are asserted plan-stable: neither may show a temporary
B-tree sort. The index change is folded into V82 before it ships.

### Parent-state trigger redefinition

V82 adds `sessions.owner_claim_id`, so the exhaustive parent-state trigger is
dropped and recreated with that column in its `UPDATE OF` list:

```sql
DROP TRIGGER sessions_parent_state_au;
CREATE TRIGGER sessions_parent_state_au
AFTER UPDATE OF parent_id, model_harness, model_id, opaque_host_id,
  project_hash, start_ms, end_ms, ingested_ms, source_path, source_format,
  schema_version, git_branch, git_worktree, git_tracking, tool_version,
  pushed_at, tags, index_version, indexed_at, license_id, session_origin,
  origin_version, session_entries_hash, source_fingerprint, session_cwd,
  publication_capture_revision, index_format_version, adapter_version,
  artifact_hash, metric_seed_json, indexed_input_hash, active_generation_id,
  root_session_id, session_purpose, input_submission_count,
  content_sweep_pending, thinking_level, thinking_level_raw,
  thinking_level_history, latest_attempt_generation_id,
  latest_attempt_artifact_hash, latest_attempt_indexer_version,
  latest_attempt_failure_code, latest_attempt_failure_message,
  latest_attempt_captured_at_ms, latest_attempt_stats_json, owner_claim_id
ON sessions
BEGIN
  -- Body is the shipped V73 parent-state projection, unchanged.
  -- It recomputes parent_state/resolved_parent_id and bumps store_state.revision.
  ...
END;
```

The trigger is exhaustive: every pointer write is an `UPDATE OF ... owner_claim_id`,
so each claimed session re-runs the parent-state projection and the
`store_state.revision` bump. A claim of N sessions therefore costs N trigger
executions on top of the indexed pointer update; it is bounded per row, not a
table rewrite. The migration carries the full V73 body; only the changed
`UPDATE OF` list is shown here.

The next migration number is selected from live source at implementation time;
at the time of writing it is V82. The migration is forward-only and immutable
once shipped. `baseline_schema.sql` is regenerated from the migration chain.

## CLI

```text
peasant user show [--json]
peasant user claim [--all] [--json]
```

`user show` reports the local owner id, the claim log newest first, ownership
counts, and prompt state. It needs no Village login and makes no network call.
`user claim` requires a valid saved Village credential. No flag claims only
unclaimed artifacts; `--all` reassigns every local session and annotation. Both
append, always; neither rewrites history. `--all` requires `--yes` on a
terminal; a non-terminal `--all` does not require `--yes`.

An empty store answers "there is nothing to claim yet" rather than claiming
nothing silently. The message can stay: the entry is still appended, it records
the decision, and the command still returns a `claimId`. `user show` and
`user claim` normalize the Village base URL in both text and JSON output and use
the contract's field names. Progress and prompts go to stderr; machine output
goes to stdout exactly once. The text and JSON facts agree
(`user-claim-json-parity`).

The sign-in prompt offers:

1. claim only unclaimed artifacts (default)
2. claim all local sessions and annotations
3. not now

It asks once per local owner plus account scope. A non-terminal invocation does
not ask and records no decision. A claim failure leaves the prompt decidable so
`peasant user claim` can retry.

Automatic claiming is best-effort: a failure is a diagnostic and never fails
the run. The run still stores its artifacts; the next explicit claim can retry
ownership. Kickstart uses the same credential read and claimer wiring as
harvest; a credential read failure is surfaced, not ignored.

## Web

These are local HTTP surfaces and therefore schema-owned. The server decides the
prompt state; the client renders it and never re-derives the rule.

```text
GET  /api/v1/local-owner            -> LocalOwnerStatus
POST /api/v1/local-owner/claim      -> LocalOwnerClaimResult
POST /api/v1/local-owner/decline    -> LocalOwnerStatus
```

### Controls and requests

| control | request | effect |
|---|---|---|
| Claim unclaimed | `POST /api/v1/local-owner/claim`, body `{"all":false}` | Claims only rows whose pointer is `NULL`. Appends a `manual` claim entry. This is the default. |
| Claim all of this to me | `POST /api/v1/local-owner/claim`, body `{"all":true}` | Explicit reassignment of every local session and annotation. Appends a `manual` claim entry. The control must say that it reassigns existing claims. |
| Not now | `POST /api/v1/local-owner/decline` | Records `declined` for this local owner plus account scope. Appends no claim entry. |
| Settings replay | either claim control | Stays available after decline or completion; sends the same request. |

The earlier "assign all of this to me" wording is the claim-all control: it
sends `{"all":true}` and is an explicit reassignment, never the default. There
is no unlink control. A claim-all is all-or-nothing and cannot be undone per
artifact.

### Prompt states

| state | meaning |
|---|---|
| `not_applicable` | no Village account is selected. |
| `due` | signed in, with no decision for this local owner plus account scope. |
| `declined` | the person chose "not now". |
| `completed` | a claim decision was completed. |

### Wire shapes

```text
LocalOwner { id, createdAt }

LocalClaimEntry {
  id, localOwnerId,
  villageUrl, userId,          // same names/grammar as CollectiveObservationScope
  username,                    // display snapshot only
  source,                      // "manual" | "sign_in_prompt" | "automatic"
  claimedAt
}

LocalOwnerStatus {
  owner,
  claims,                      // at most 100, newest first (claimedAt DESC, rowid DESC)
  totalClaims,                 // whole-log count; decides nothing
  nextBefore?,                 // last returned id, exactly when older entries exist
  prompt,                      // LocalOwnerClaimPrompt
  ownership: { sessions: {total, claimed, unclaimed},
               annotations: {total, claimed, unclaimed} }
}

LocalOwnerClaimRequest { all bool }
LocalOwnerClaimResult { status: LocalOwnerStatus, claimed, alreadyClaimed, claimId? }
LocalOwnerClaimPrompt { state, account?, decidedAt? }

LocalArtifactIdentity {        // role-neutral; replaces LocalArtifactOwner
  kind: "local" | "village" | "foreign" | "unknown",
  localOwnerId?, villageUrl?, villageUserId?, claimId?, username?
}
```

Rules:

- `kind: "village"` carries `claimId` and `villageUrl` plus `villageUserId`; the
  account scope is never dropped.
- `kind: "local"` carries `localOwnerId` only. `localOwnerId` is 1..64 bytes.
- `kind: "unknown"` carries no identity. An empty `username` is rejected.
- An absent `owner` means this server does not project owners.
  `{"kind":"unknown"}` means the server projects ownership but withholds the
  identity. Unknown is never a local fallback.
- The claim order is newest first: `claimed_at DESC, rowid DESC`. A cursor
  resolves to its row's `(claimed_at, rowid)`.
- An automatic claim reuses an entry only when the newest entry of the log is
  this account's `automatic` entry; otherwise it appends. Explicit claims always
  append, including a claim that moves nothing and a claim on an empty store.
  `source` and `claimedAt` belong to the entry that was appended, not to each
  artifact.
- `claims` is bounded to 100 entries. `nextBefore` is the last returned entry's
  id and is present exactly when an older entry exists: with 100 returned it is
  present when a 101st row exists; with fewer than 100 returned it is absent.
  `totalClaims` is the whole-log count, so `totalClaims >= len(claims)`, and it
  decides nothing. Automatic reuse keeps the log from growing by one entry per
  harvest; explicit claims can still grow it.
- All three routes answer with the same `LocalOwnerStatus` shape. The claim
  route wraps it as `status` and adds `claimed`, `alreadyClaimed`, and
  `claimId?`.
- `LocalAnnotationRow` embeds `AnnotationSummary`. Add the embedding to
  `expandedEmbeddedRequired`, regenerate the contract, and pin the nine summary
  fields as required plus `owner` and `author` as optional non-null.

### Statuses

| route | statuses | meaning |
|---|---|---|
| `GET /api/v1/local-owner` | 200, 500 | 500 is a store or projection failure. |
| `POST /api/v1/local-owner/claim` | 200, 400, 401, 500 | 400 is an invalid body or `all` value; 401 is no valid saved credential; 500 is a store failure. These routes never call Village. |
| `POST /api/v1/local-owner/decline` | 200, 401, 500 | 401 is no signed-in account to key the scope; 500 is a store or state-file failure. |

The read, claim and decline answers use the same status shape; claim adds the
result fields. No body repeats the HTTP status.

### Versions

The number and pair are chosen from live source at implementation time. On
2026-11-18 the current choice is **Local 0.39.0 / Types 0.52.0**, retiring
0.38.0 / 0.51.0. `PeasantLocalAPIVersion = 0.39.0` is still free, while Types
0.51.0 is already released on `develop` with different content, so the types
version moves past it. `peasant-labs/schema#219` targets that pair and freezes
0.38.0 / 0.51.0 in `retired_specs.yaml` with its pinned hashes; do not mutate a
retired spec. Regenerate with `make schema`; never hand-merge generated files.

The schema change is additive: a schema release, followed by consumer re-pins.
Until the schema tag exists, consumers co-develop with a local `go.work` and
never commit a `replace` directive.

## Milestone B projections

No new tables if the evidence below holds:

1. `internal/pull/manifest.go` already carries `ownerUserId`,
   `ownerUsername`, `authorUserId` and `authorUsername` for every pulled
   transcript and annotation.
2. The Village already knows the account that published a transcript; the push
   path needs no served owner field.
3. Producer stamps already travel with a transcript and are indexed locally.

The read-side additions are additive local fields:

- `SessionSummary`, `LocalSyncSummary`, and `SessionDetailReadPayload` gain an
  optional `owner` (`LocalArtifactIdentity`) and `adapterVersion`.
- `LocalAnnotationRow` embeds `AnnotationSummary` and gains optional `owner` and
  `author` without changing the shared `AnnotationSummary` or the Village pull
  envelope.
- A pulled transcript or annotation always derives owner/author from its pull
  manifest. An empty manifest owner renders as `{"kind":"unknown"}`, never as
  the local holder.
- A pulled row reports producer `unknown` unless the pull contract later carries
  producer stamps.
- Absent `owner` and `{"kind":"unknown"}` are different answers: absent means
  the server does not project owners; unknown means it projects them and cannot
  name this one.

## Named cases

The migration and CLI changes ship these cases. Fixtures are strict, typed
`testdata` files; a case names the artifact it expects, not only a count. The
store cases live in `internal/store/testdata/local_owner_claim_cases.yaml`.

- `claim-never-touches-pulled-transcripts`
- `owner-pulled-never-shows-local-holder`
- `claim-reassign-other-account-retains-entries` (was
  `claim-unlink-and-reclaim-other-account`; it tests an all-or-nothing
  reassignment, not an unlink)
- `auto-claim-session-first-seen-active`
- `auto-claim-skips-forced-reprocess`
- `auto-claim-skips-web-one-session-ingest`
- `auto-claim-skips-rebuild-from-saved-pairs`
- `auto-claim-skips-updated-unclaimed-session`
- `auto-claim-skips-reindexed-sessions`
- `auto-claim-skips-rebuilt-sessions`
- `auto-claim-after-decline-covers-only-new-sessions`
- `auto-claim-leaves-other-account-rows`
- `auto-claim-leaves-other-account-annotations`
- `auto-claim-after-reassign-back`
- `auto-claim-after-own-manual-claim`
- `auto-claim-reuses-newest-automatic`
- `claim-default-nothing-to-move-appends-entry`
- `claim-empty-store-appends-entry`
- `owner-created-after-upgrade-from-v81`
- `read-only-open-creates-no-owner`
- `owner-file-mismatch-refused`
- `user-claim-json-parity`

Additional required proofs:

- The four first-stored cases are pipeline-level tests, not pure-function unit
  tests: `auto-claim-session-first-seen-active`,
  `auto-claim-skips-forced-reprocess`, `auto-claim-skips-web-one-session-ingest`,
  `auto-claim-skips-rebuild-from-saved-pairs`.
- Rebuild adoption: remove `peasant.db`, reopen the store, and assert the same
  local owner id and `createdAt` from `local-owner.json`.
- Rebuild limit: after the same rebuild, assert the claim log is empty and every
  artifact pointer is `NULL`.
- `TestMigrationV82AddsLocalOwnerAndClaimLog` proves that each of these fails: a
  second `local_owner` insert, `UPDATE local_owner`, `DELETE local_owner`,
  `INSERT OR REPLACE` into `owner_claims`, `UPDATE owner_claims`, and `DELETE
  owner_claims`.
- The page read and the reuse lookup both report no temporary B-tree sort; a
  query-plan assertion fails on `USE TEMP B-TREE`.
- Contract paging cases: `owner-status-final-older-page` (50 of 250, no cursor)
  and `owner-status-full-last-page` (100 of 200, no cursor) must pass, while
  `owner-status-cursor-on-short-page` and `owner-status-ascending-page` must
  fail.
- Removing `owner_claim_id IS NULL` or the account filter from a claim must make
  a case fail.
- Removing `FirstStored` in favour of `DiffNew` must fail
  `auto-claim-session-first-seen-active` and
  `auto-claim-skips-forced-reprocess`.
- Removing strict reuse must fail `auto-claim-after-reassign-back` and
  `auto-claim-after-own-manual-claim`.
- The `ClaimSource` parser rejects an unknown source and the set test asserts
  exact membership.
- The claim path is measured on a synthetic large store and the margin is
  reported in the implementation PR.
- schema#219 adds the owner-status and claim-entry fixtures, the prompt-state
  enum cases, the must-pass/must-fail identity cases, and the requiredness and
  error-status fixtures from its review.

## Migration review account

- The migration applies to a populated V81 fixture database, not a hand-written
  schema.
- `baseline_schema.sql` is regenerated from the migration chain.
- The exact-name schema catalog, migration-slot registry, predecessor pin and
  hardcoded head-version assertions move to V82 in the same change.
- The migration comment records that the claim FK joins the
  collective-observation scope cache and that a claimed scope row is permanent;
  claim code never deletes a scope row.
- The parent-state trigger redefinition is exercised by a pointer write.
- Shipped migrations are not edited.

## Merge dependencies

- Nothing must merge before this record. It is documentation only: it changes
  no code, contract or migration, and is safe to merge on its own.
- `peasant-labs/peasant#951` waits for this record. It must not merge until this
  revision lands. V82 is immutable once shipped, so a wrong automatic-claim rule
  or DDL cannot be corrected forward-only.
- `peasant-labs/schema#219` waits for this record. It must not merge until this
  revision lands and it has moved to the version pair named under Versions.
- Both implementation PRs are built from this record and each must address its
  own review and rebase before merge. The maintainers decide the merge order.
  The rulings here still govern them: if either lands first, it must match this
  record, and the other must follow rather than redo a contract or migration in
  a different shape.
- The schema release follows schema#219; the peasant re-pin follows the schema
  tag. Neither blocks merging this record.

## Out of scope

- A per-artifact unlink, coverage table, or termination record. A termination
  table is additive later; nothing in V82 prevents it.
- Comments on other people's transcripts.
- Fork or continuation of another person's transcript.
- Review requests and delegation chains.
- Changing ownership of already-pushed artifacts on the Village.
- The publication-history epic and its ledger.
- The multiplayer harness.
- Publishing the schema tag or merging consumer re-pins in this change.

## C4 model

```c4
Container diagram: peasant

+---------------------------+
| developer                 |
| [Person]                  |
| Records agent sessions,   |
| then claims them.         |
+---------------------------+
         |              |
         |              +-- opens the local app (browser, HTTP) ----------------+
         |                                                                      |
         | runs the user, login, and harvest                                    |
         | commands (CLI)                                                       |
         v                                                                      v
+== peasant [Software System] ========================================================================+
|                                                                                                     |
|  +---------------------------+                                        +---------------------------+ |
|  | peasant backend           |<-- reads and claims ownership (HTTP) --| peasant web               | |
|  | [Container: Go]           |                                        | [Container: Next.js 15]   | |
|  | Runs the user commands,   |                                        | Claim control on the      | |
|  | the prompt, and ingest.   |                                        | local API owner routes.   | |
|  +---------------------------+                                        +---------------------------+ |
|        |              |                                                                             |
|        |              +-- reads account, records prompt (JSON files) ---------+                     |
|        |                                                                      |                     |
|        | appends claims, sets owner                                           |                     |
|        | pointers (SQL, owner/claim migration)                                |                     |
|        v                                                                      v                     |
|  +---------------------------+                                        +---------------------------+ |
|  | peasant session store     |                                        | account and prompt files  | |
|  | [Container: SQLite]       |                                        | [Container: JSON files]   | |
|  | Sessions, annotations,    |                                        | Saved credential and      | |
|  | local owner, claim log.   |                                        | claim prompt decisions,   | |
|  | Owner id file beside it.  |                                        | keyed by owner + scope.   | |
|  +---------------------------+                                        +---------------------------+ |
|                                                                                                     |
+=====================================================================================================+

Key:
  Solid box = element. Double-line box = boundary. [Type] = C4 abstraction.
  Arrow = one relationship, read as "source, label (technology), target".
```

This record rules the store arrow (the owner/claim migration) and the web arrow
(the local API owner routes). No claim path calls Village: the store claim path
and the web claim route read only local state and local credential files.
