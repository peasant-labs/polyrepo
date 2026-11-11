# Local-first identity and ownership

Status: proposed for `peasant-labs/polyrepo#71`, with child issues
`peasant-labs/peasant#890` (Milestone A) and `peasant-labs/peasant#891`
(Milestone B).

## Authority and scope

`peasant-labs/polyrepo#71` is the authority for the end state and guardrails.
The two child issues carry the decided scope for the implementation.

The epic names a Pasture requirements record, elicitation record and epic
record under `https://github.com/peasant-labs/peasant/<uuid>`. Those records are
not present in this checkout and return 404 from this environment. This
proposal therefore relies on the decided scope written in the child issues and
states every remaining choice explicitly. If the Pasture records disagree,
they win and this document is amended before the migration is reviewed.

## End state

One `peasant` data directory holds one permanent local owner. Local sessions
and annotations carry an owner that is either that local owner or the Village
account that claimed them. Claims are append-only. Pulled transcripts and
pulled annotations remain foreign, one way and non-republishable.

Every surface keeps three roles distinct:

| role | meaning | source |
|---|---|---|
| owner | whose artifact this is in the local store | this proposal's local owner and claim log; the pull manifest for foreign rows |
| author | who wrote a message or annotation | transcript content and the pull manifest's annotation authors |
| producer | which adapter and indexer produced it | existing `adapter_version`, `session_origin`, `origin_version`, `index_version` stamps |

## Decisions

### 1. Where "claimed" is recorded

A current pointer plus an append-only log:

- `sessions.owner_claim_id` and `annotations.owner_claim_id` are nullable text
  columns. `NULL` means unclaimed.
- `owner_claims` is the append-only log. A claim appends one entry and then
  sets the current pointer on the artifacts it covers.
- The pointer has no foreign key. `PruneSessions` must keep working, and a
  claim entry must survive the artifact it covered. The log is the history; the
  pointer is the current projection.

Consequence: "claim only unclaimed" is one indexed `UPDATE ... WHERE
owner_claim_id IS NULL` per artifact table. A claim over thousands of sessions
and annotations is a bounded write transaction, not a full table rewrite. The
history remains complete after artifacts are pruned because `owner_claims` has
no artifact foreign key. Re-claiming overwrites only the current pointer; it
never rewrites an earlier log entry.

### 2. Claim granularity

A claim covers local sessions and local annotations.

- Sessions: every row in `sessions`.
- Annotations: every row in `annotations`, including classifier output. The
  owner of an annotation is the owner of the local store, not the classifier
  persona. `annotator_id` remains the author/producer-side label and is not
  reused as owner.
- Bindings and associations (`session_commit_associations`,
  `session_generation_associations`, and target rows) are not separate artifact
  classes. They inherit their session's owner.
- Pulled rows (`pulled_transcripts`, `pulled_annotations`) are never claimed
  and never written by claim code.

### 3. Unlink semantics

Milestone A has no separate unlink record and no "unlinked" claim state.

- Signing out does not remove a claim. A claim is a completed action and stays
  as historical evidence.
- A later claim from another Village account appends a new entry and moves the
  current pointer. Earlier entries remain unchanged.
- `claim --all` is an explicit reassignment. It is documented as such. It does
  not delete history.
- Lost or revoked Village access grants nothing. The claim remains evidence
  only.

### 4. Claim time vs ingest time

The current pointer is authoritative for ownership. The log is ordered by
`claimed_at` and each entry has a stable id.

- A manual claim records the wall-clock claim time.
- An automatic claim at the end of a harvest appends one entry for that batch.
  It points only at artifacts created or updated by that run, so it cannot
  accidentally cover an older claim.
- No historical claim times are invented for existing installations. Existing
  rows start with `owner_claim_id = NULL`.
- An artifact created before a claim but never claimed is covered by the next
  default claim, because "unclaimed" is the pointer being `NULL`, not an
  ingest-time comparison.

### 5. Account scope

A claim entry reuses the account scope from `polyrepo#37`:
`CollectiveObservationScope` is a normalized, full Village base URL plus a
stable Village user UUID. The username is a display snapshot only.

The claim row stores `village_url` and `user_id` using the same names and
grammar as `collective_observation_scopes`, and references that scope with a
composite foreign key. The scope row is created idempotently when a claim is
written; claim code does not bump the collective-observation invocation
sequence.

### 6. Decline state

A decline is not a claim. It records only that the prompt was dismissed for
one account scope, so the product does not nag. It lives in runtime state
(`<state-dir>/peasant/claim-prompt.json`), keyed by normalized Village base URL
plus Village user UUID. It is never written to `owner_claims`.

## Storage

Migration V76 is the next slot in the live source. It adds:

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
    source            TEXT NOT NULL CHECK (source IN ('sign_in_prompt','automatic','manual')),
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

CREATE INDEX idx_owner_claims_owner_order
    ON owner_claims(local_owner_id, claimed_at, id);

CREATE INDEX idx_owner_claims_scope_order
    ON owner_claims(village_url, user_id, claimed_at, id);

ALTER TABLE sessions ADD COLUMN owner_claim_id TEXT;
ALTER TABLE annotations ADD COLUMN owner_claim_id TEXT;

CREATE INDEX idx_sessions_owner_claim ON sessions(owner_claim_id);
CREATE INDEX idx_annotations_owner_claim ON annotations(owner_claim_id);
```

The next migration number is selected from live source at implementation time;
at the time of writing it is V76. The migration is forward-only and immutable
once shipped.

## CLI

```text
peasant user show [--json]
peasant user claim [--all] [--json]
```

`user show` reports the local owner id and the ordered claim log. It needs no
Village login and makes no network call. `user claim` requires a valid saved
Village credential; no flag claims only unclaimed artifacts, `--all` claims
every local session and annotation. Both append; neither rewrites history.
Progress and prompts go to stderr; machine output goes to stdout exactly once.

The sign-in prompt offers:

1. claim only unclaimed artifacts (default)
2. claim all local sessions and annotations
3. not now

It asks once per account scope per data directory. A non-terminal invocation
does not ask and records no decision. A claim failure leaves the prompt
decidable so `peasant user claim` can retry.

## Web

The claim control is "assign all of this to me"; the decline control is "not
now". The claim control stays available in settings after decline or
completion.

These are local HTTP surfaces and therefore schema-owned. The minimal contract
addition is:

```text
GET  /api/v1/local-owner            -> LocalOwnerStatus
POST /api/v1/local-owner/claim      -> LocalOwnerStatus
POST /api/v1/local-owner/decline    -> LocalOwnerStatus
```

`LocalOwnerStatus` carries the local owner, the ordered claim entries, and the
prompt's decline state. It reuses `CollectiveObservationScope` for claim
entries. No Village route, publish type, or pulled-manifest field changes.

The schema change is additive: Local API 0.36.0 and Types 0.48.0 in a schema
release, followed by consumer re-pins. Until the schema tag exists, consumers
co-develop with a local `go.work` and never commit a `replace` directive.

## Milestone B projections

No new tables if the evidence below holds:

1. `internal/pull/manifest.go` already carries `ownerUserId`, `ownerUsername`,
   `authorUserId` and `authorUsername` for every pulled transcript and
   annotation.
2. The Village already knows the account that published a transcript; the push
   path needs no served owner field.
3. Producer stamps already travel with a transcript and are indexed locally.

The read-side additions are additive local fields:

- `SessionSummary`, `LocalSyncSummary`, and `SessionDetailReadPayload` gain an
  optional `owner` and `adapterVersion`.
- A local annotation read envelope gains optional `owner` and `author` without
  changing the shared `AnnotationSummary` or the Village pull envelope.
- A pulled transcript or annotation always derives owner/author from its pull
  manifest. An empty manifest owner renders as `unknown`, never as the local
  holder.
- A pulled row reports producer `unknown` unless the pull contract later carries
  producer stamps.

## Migration review account

- The migration applies to a populated V75 fixture database, not a hand-written
  schema.
- `baseline_schema.sql` is regenerated from the migration chain.
- The exact-name schema catalog, migration-slot registry, predecessor pin and
  hardcoded head-version assertions move to V76 in the same change.
- Tests include the named cases in `peasant#890` and `peasant#891`, including
  `claim-never-touches-pulled-transcripts` and
  `owner-pulled-never-shows-local-holder`.
- Shipped migrations are not edited.

## Out of scope

- Comments on other people's transcripts.
- Fork or continuation of another person's transcript.
- Review requests and delegation chains.
- Changing ownership of already-pushed artifacts on the Village.
- The publication-history epic and its ledger.
- The multiplayer harness.
- Publishing the schema tag or merging consumer re-pins in this change.
