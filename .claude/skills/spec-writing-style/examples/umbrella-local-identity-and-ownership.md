<!-- Reference snapshot. Source: https://github.com/peasant-labs/polyrepo/issues/71
     Title: [P1][Epic] Local-first identity and ownership (cross-repo)
     Body is verbatim as published; edit the issue, not this file. -->

## Why

A peasant data directory now holds transcripts, annotations, claimable shares and pull indexes,
and none of them records who owns the artifact. Two developers who share one machine cannot tell
whose session is whose. One developer with two Village accounts cannot tell which account claimed
which session. This is the last large local surface with no owner.

The foreign half of the problem is already solved and must stay solved. A pulled transcript
carries `ownerUserId`, `ownerUsername` and per-annotation `authorUserId`, `authorUsername` in
`internal/pull/manifest.go`, and `internal/store/pull_store.go` indexes those manifests as a
derived, one-way, non-repushable view of another person's work.

The work has a dated driver. The NeurIPS 2026 agent-native AI research workshop runs around
2026-12-12. Only Milestone A and Milestone B must be demo-ready; nothing else in this epic must.
The wider product goal is public digital infrastructure for conference organizers to ingest and
manage transcripts from authors and peer reviewers.

## Concept map

```text
                        one peasant data directory
                                  |
                  +---------------v-----------------+
                  |  local owner (one, permanent)   |
                  |  created automatically          |
                  +---------------+-----------------+
                                  |
                        claim log (append only)
                        local owner id
                        Village base URL
                        Village user UUID          <- identity
                        username                   <- display snapshot only
                        claim time
                                  |
        +-------------------------+--------------------------+
        |                                                    |
   local artifacts                                  Village accounts
   sessions, annotations                            stable UUID at a base URL
   claimed by the local owner                       username can change, can be reused
   or by a Village account                                 |
        |                                                  |
        v                                                  v
  +-----+-------------------------------+        (claim prompt at sign-in)
  |  CLI: peasant user show / claim     |
  |  web: "assign all of this to me"    |
  |       "not now", and settings keeps |
  |       the control                   |
  +-----------------+-------------------+
                    |
                    v
          every surface shows three roles, never one:
          owner   = whose artifact this is locally
          author  = who wrote a message or annotation
          producer= which adapter and indexer produced it (existing stamps)
                    |
                    v
     pulled transcripts stay FOREIGN, one way, non-repushable:
     owner and author come from the pull manifest, never from the local holder
```

## Scope

### Milestone A — local identity and claims (child: peasant-labs/peasant#890)

One permanent local owner per data directory, created automatically with no Village login. An
append-only claim log in the account-scoped store. Automatic claim of new artifacts while signed
in. A sign-in prompt that claims only unclaimed artifacts by default, with a claim-all option.
A `user` command group. One web claim control plus a decline control that stays available in
settings. Existing installations start unclaimed and are prompted once. One forward-only
migration.

### Milestone B — ownership shown everywhere (child: peasant-labs/peasant#891)

Owner attached to locally ingested sessions and annotations. Pulled transcripts and their
annotations always show the remote owner and author from the manifest. The collective view shows
whose transcript came from whom. Owner, author and producer stay three distinct roles, with the
producer role reusing the existing adapter and indexer stamps.

## Identity vocabulary

- **Local owner** — a permanent identifier for one peasant data directory. Not a Village account. Not a username. Not an email address. Created once, never recreated by signing out.
- **Village account** — a stable Village user UUID at a normalized full Village base URL. This is the same scope that the offline collective observations already define (peasant-labs/polyrepo#37). Do not define a second scope rule.
- **Claim** — one append-only log entry that links the local owner to a Village account at a point in time. A claim never deletes an earlier claim.
- **Owner, author, producer** — three roles. Owner is whose artifact this is in the local store. Author is who wrote a given message or annotation. Producer is which adapter and indexer produced the transcript.

## Guardrails

1. **Account-scoped state stays separate from account-neutral pulled rows.** The claim log is account-scoped. `pulled_transcripts` and `pulled_annotations` are account-neutral indexes of on-disk manifests. Never write a local owner into a pulled row.
2. **Last observation, historical outcome and intended action stay separate records.** A claim is a completed action. A declined prompt is not a claim. A pending intent is not a claim. Do not collapse them into one status field.
3. **`targetLocalId` stays owner-local.** It identifies content under one owner. Never stretch it to represent a foreign owner, and never use it to bridge two accounts.
4. **Pulled transcripts stay foreign, one way and non-repushable.** A claim never makes another person's pulled transcript yours. A pulled row never becomes a republish candidate.
5. **Lost Village access is never reconstructed into local authority.** A revoked or unreachable Village account does not become a local owner. The claim entry stays as historical evidence and grants nothing.
6. **The migration is deliberate.** One forward-only SQLite migration. It becomes immutable once shipped. Review it as a durable schema change, not as an implementation detail.

## Wire state

**No new wire state is expected, and the proposal must confirm that with evidence.**

- `internal/pull/manifest.go` already carries the remote owner and the remote annotation authors for every pulled transcript.
- The Village already knows the account that published a transcript, so a pushed local artifact acquires its remote owner from the publishing account.
- The producer stamps already travel with a transcript and are already indexed locally as `adapter_version`, `session_origin` and `origin_version`.

If a real gap appears, it becomes its own contract change in peasant-labs/schema, with its own
release before a consumer re-pins. A local field is never called shared.

## Roadmap after this epic

Recorded so the later work is not lost. These are not tasks, and this epic does not start them.
Order is a dependency order, not a schedule.

1. **Comments on other people's transcripts.** Requires a foreign-author identity that survives the claim model, and a disclosure rule for the transcript's owner.
2. **Fork and continue another person's transcript.** The inherited agent configuration must freeze as an immutable copy at fork time. Otherwise the source owner can change code the fork later executes.
3. **Review requests and delegation chains.** The "initiator" role appears here: one person asks a second, who asks a third.
4. **Village ownership transfers with source-owner consent**, recorded in the publication ledger.
5. **A multiplayer harness** that runs these flows between real accounts.

## Out of scope

- Comments on other people's transcripts.
- Fork or continuation of another person's transcript.
- Review requests and delegation chains.
- Changing ownership of already-pushed artifacts on the Village. That needs source-owner consent and depends on the deferred publication-history work.
- The publication-history epic peasant-labs/peasant#356 and its children. It is deferred. When it lands, ownership-transfer events must join its ledger rather than growing a second journal.
- The multiplayer harness itself.

## Reading and review order

1. Read this issue for the end state, the guardrails and the role split.
2. Read the Milestone A issue for the owner record, the claim log, the command surface and the migration. Review the migration as its own subject.
3. Read the Milestone B issue for the read-side projections and the three-role display.
4. Review the claim log against the pull index together. The dangerous mistake is one write that spans both.
5. Review the mounted web surfaces for the claim prompt, the settings control, and the owner line in the gallery, the reader and the collective view.

## Merge dependencies

- **What must land first:** the requirements record must exist, then a reviewed proposal, then the migration review. A schema change lands only if a real wire gap appears, in its own repository and its own release.
- **Is anything here safe to merge alone:** nothing is safe to merge before its schema and contract needs are known. The migration is not safe to ship before the claim semantics are settled.
- **No pull requests exist yet.** This issue records scope. No branch, migration, release or deployment exists for it.
- **What breaks if it merges too early:** a migration that ships before the claim semantics settle is a forward-only record of a guess. A display that ships before Milestone A lands either shows nothing or invents an owner.

## Related

- peasant-labs/polyrepo#37 — offline collective metadata and contribution history. It owns the account scope (normalized Village base URL plus stable Village user UUID) that this epic reuses.
- peasant-labs/peasant#356 — parser provenance and publication history. Deferred. The future home of ownership-transfer events.
- peasant-labs/polyrepo#68 — collective contribution at library scale. Separate initiative; no overlap in stored state.

## Decision record

The requirements, the elicited decisions and the guardrails live in the Pasture tasks for this
epoch, in the `https://github.com/peasant-labs/peasant` namespace:

- request: `https://github.com/peasant-labs/peasant/01a1c3b7-1145-7d53-ab30-e51cbc881bc7`
- elicitation: `https://github.com/peasant-labs/peasant/01a1c3b7-2756-7361-a868-523e118d9bfe`
- requirements: `https://github.com/peasant-labs/peasant/01a1c3b7-37e6-7c3f-94af-bbc592ed8a85`
- epic: `https://github.com/peasant-labs/peasant/01a1c3b8-1066-75d9-87c5-36372ef2b55f`
