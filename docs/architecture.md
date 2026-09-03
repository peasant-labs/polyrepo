# How peasant-labs fits together

This guide is for a contributor who has cloned the workspace and wants to know where a change
belongs. It starts with the problem, then zooms from the whole workspace into the two runtime
systems. The diagrams use the [C4 model](https://c4model.com/) and plain ASCII so they render in
GitHub and terminals.

## Why this project exists

AI coding tools record useful work, but their session data stays in separate local formats. That
makes a session hard to review, connect to Git history, redact, and share. Peasant-labs provides a
local-first path from those private records to a public transcript commons:

1. **Peasant** reads local agent sessions and connects them to repositories and commits.
2. The developer reviews the transcript and applies the shared redaction rules.
3. The developer chooses what to publish and gives explicit consent.
4. **Village** validates the shared wire contract, stores the published copy, enforces access and
   governance rules, and makes allowed transcripts discoverable.
5. Both user interfaces use the same transcript components, so the local review and published
   reading experience do not drift.

The system keeps local discovery separate from access control. A selection rule can hide a local
session from lists, but it does not revoke access to data that is already stored. Publication is a
separate, user-initiated action.

## Where a change belongs

Some repositories run applications. Other repositories provide shared libraries or workspace
tools. A C4 container is a runnable application or data store, so the shared libraries appear as
technology labels in the diagrams instead of standalone boxes.

| Repository | Responsibility | Start with |
|---|---|---|
| `peasant` | Local ingestion, indexing, Git association, review, redaction, and sharing. | `peasant/develop/AGENTS.md` |
| `village` | Published transcript registry, access control, discovery, governance, and storage. | `village/develop/AGENTS.md` |
| `schema` | Canonical Go and TypeScript wire contract, validators, fixtures, and generated specifications. | `schema/develop/AGENTS.md` |
| `redact` | Canonical redaction categories, rules, fixtures, and rule-set versions. | Repository README and tests. |
| `fairtrade-design-system` | Shared themes, transcript rendering, adapters, and graph UI. | `fairtrade-design-system/main/AGENTS.md` |
| `website` | Public project website and installer delivery. | `website/AGENTS.md` |
| `polyrepo` | Checkout, synchronization, toolchain setup, and contributor orientation. | `README.md` |

Wire-contract changes land and receive a `schema` tag before consumers update their pins. Redaction
engine changes follow the same tag-before-repin rule. User-interface consumers adopt fairtrade;
they do not redefine its transcript rendering or design tokens.

## System landscape

This view shows the people and runtime systems. It does not show repositories that contain only
libraries or development tools.

### Model

| Name | Type | Technology | Description |
|---|---|---|---|
| developer | Person | | Records coding sessions with an AI agent. |
| reader | Person | | Browses published transcripts. |
| peasant | Software System | | Ingests, indexes, and serves the developer's agent sessions locally. |
| village | Software System | | Provides the registry and commons for published transcripts. |
| agent session stores | Software System, external | | OpenCode, Claude Code, and Cursor local stores. |

| Source | Target | Intent | Technology |
|---|---|---|---|
| developer | peasant | reviews, redacts, and shares sessions | browser |
| reader | village | browses published transcripts | browser |
| peasant | village | publishes a reviewed session | HTTPS |
| peasant | agent session stores | reads session files and rows | JSONL, SQLite |

```c4
System Landscape diagram: peasant-labs

+-----------------------------+                                  +-----------------------------+
| developer                   |                                  | reader                      |
| [Person]                    |                                  | [Person]                    |
| Records coding sessions     |                                  | Browses published           |
| with an AI agent.           |                                  | transcripts.                |
+-----------------------------+                                  +-----------------------------+
              |                                                                |
              | reviews, redacts, and                                          | browses published
              | shares sessions (browser)                                      | transcripts (browser)
              v                                                                v
+-----------------------------+                                  +-----------------------------+
| peasant                     |-- publishes a session (HTTPS) --->| village                     |
| [Software System]           |                                  | [Software System]           |
| Ingests, indexes, and       |                                  | Provides the registry and   |
| serves the developer's      |                                  | commons for published       |
| agent sessions locally.     |                                  | transcripts.                |
+-----------------------------+                                  +-----------------------------+
              |
              | reads session files and rows (JSONL, SQLite)
              v
+-----------------------------+
| agent session stores        |
| [Software System, external] |
| OpenCode, Claude Code, and  |
| Cursor local stores.        |
+-----------------------------+

Key:
  Solid box = element. [Type] = C4 abstraction. "external" = outside the diagram scope.
  Arrow = one relationship, read as "source, label (technology), target".
```

## Inside Peasant

Peasant runs on the developer's machine. Its backend owns ingestion and policy. Its web application
shows the resulting sessions. SQLite keeps the local record.

### Model

| Name | Type | Technology | Description |
|---|---|---|---|
| peasant web | Container | Next.js 15 | Renders transcripts with fairtrade and hosts `/share`. |
| peasant backend | Container | Go | Ingests, indexes, redacts, and serves sessions. |
| peasant session store | Container | SQLite | Holds sessions, turns, commits, and share state. |
| agent session stores | Software System, external | JSONL, SQLite | Hold records written by AI coding tools. |
| village | Software System, external | HTTPS | Receives reviewed publications. |
| developer | Person | browser | Reviews local sessions and starts publication. |

| Source | Target | Intent | Technology |
|---|---|---|---|
| developer | peasant web | opens the local application | browser, HTTP |
| peasant web | peasant backend | subscribes to session detail | WebSocket |
| peasant backend | peasant session store | reads and writes session state | SQL |
| peasant backend | agent session stores | reads session files and rows | JSONL, SQLite |
| peasant backend | village | publishes a reviewed session | HTTPS, schema wire |

```c4
Container diagram: peasant

+-----------------------------+
| developer                   |
| [Person]                    |
+-----------------------------+
              |
              | opens the local application (browser, HTTP)
              v
+== peasant [Software System] ===================================================================+
|                                                                                                |
|  +-----------------------------+                                                               |
|  | peasant web                 |                                                               |
|  | [Container: Next.js 15]     |                                                               |
|  | Renders transcripts with    |                                                               |
|  | fairtrade. Hosts /share.    |                                                               |
|  +-----------------------------+                                                               |
|                |                                                                               |
|                | subscribes to session detail (WebSocket)                                      |
|                v                                                                               |
|  +-----------------------------+                                +-----------------------------+ |
|  | peasant backend             |-- reads and writes (SQL) ----->| peasant session store       | |
|  | [Container: Go]             |                                | [Container: SQLite]         | |
|  | Ingests, indexes, redacts,  |                                | Holds sessions, turns,      | |
|  | and serves sessions.        |                                | commits, and share state.   | |
|  +-----------------------------+                                +-----------------------------+ |
|           |                 |                                                                  |
|           |                 +-- publishes a reviewed session (HTTPS, schema wire) --+          |
|           |                                                                         |          |
+===========|=========================================================================|==========+
            | reads session files and rows                                            |
            | (JSONL, SQLite)                                                         v
            v                                                           +-----------------------------+
+-----------------------------+                                         | village                     |
| agent session stores        |                                         | [Software System, external] |
| [Software System, external] |                                         | Receives reviewed           |
| Hold records written by AI  |                                         | publications.               |
| coding tools.               |                                         +-----------------------------+
+-----------------------------+

Key:
  Solid box = element. Double-line box = boundary. [Type] = C4 abstraction.
  "external" = outside the diagram scope. Arrow = one relationship, read as
  "source, label (technology), target".
```

## Inside Village

Village is the hosted commons. Its frontend serves readers. Its backend validates publications,
enforces access rules, and splits metadata from transcript objects. Development uses PostgreSQL 16
and MinIO. Production uses Railway PostgreSQL and Cloudflare R2 through the same SQL and S3 APIs.

### Model

| Name | Type | Technology | Description |
|---|---|---|---|
| village frontend | Container | Next.js 16 | Provides authentication, discovery, and transcript views. |
| village backend | Container | Go | Validates publications and enforces access and governance rules. |
| village database | Container | PostgreSQL 16 | Holds users, registry metadata, access state, and governance audit rows. |
| village blob store | Container | S3-compatible object storage | Holds encrypted transcript objects. |
| reader | Person | browser | Browses transcripts that policy allows. |

| Source | Target | Intent | Technology |
|---|---|---|---|
| reader | village frontend | browses published transcripts | browser, HTTPS |
| village frontend | village backend | calls the registry API | HTTPS, JSON |
| village backend | village database | reads and writes metadata | SQL |
| village backend | village blob store | stores and reads encrypted transcripts | S3 API, HTTPS |

```c4
Container diagram: village

+-----------------------------+
| reader                      |
| [Person]                    |
+-----------------------------+
              |
              | browses published transcripts (browser, HTTPS)
              v
+== village [Software System] ===================================================================+
|                                                                                                |
|  +-----------------------------+                                                               |
|  | village frontend            |                                                               |
|  | [Container: Next.js 16]     |                                                               |
|  | Provides authentication,    |                                                               |
|  | discovery, and views.       |                                                               |
|  +-----------------------------+                                                               |
|                |                                                                               |
|                | calls the registry API (HTTPS, JSON)                                          |
|                v                                                                               |
|  +-----------------------------+                                +-----------------------------+ |
|  | village backend             |-- reads and writes (SQL) ----->| village database            | |
|  | [Container: Go]             |                                | [Container: PostgreSQL 16]  | |
|  | Validates publications and  |                                | Holds registry metadata     | |
|  | enforces policy.            |                                | and governance audit rows.  | |
|  +-----------------------------+                                +-----------------------------+ |
|                |                                                                               |
|                | stores and reads encrypted transcripts (S3 API, HTTPS)                         |
|                v                                                                               |
|  +-----------------------------------------------+                                             |
|  | village blob store                            |                                             |
|  | [Container: S3-compatible object storage]     |                                             |
|  | Holds encrypted transcript objects.           |                                             |
|  +-----------------------------------------------+                                             |
|                                                                                                |
+================================================================================================+

Key:
  Solid box = element. Double-line box = boundary. [Type] = C4 abstraction.
  Arrow = one relationship, read as "source, label (technology), target".
```

## What happens when a developer shares a session

This dynamic view shows runtime order. It is not a replacement for the static container views.
The schema module defines the wire used in step 5. The redact module supplies the rules used before
the developer consents. Fairtrade supplies the transcript and review components in Peasant web.

### Model

| Step | Source | Target | Intent | Technology |
|---|---|---|---|---|
| 1 | developer | peasant web | opens `/share` | browser, HTTP |
| 2 | peasant web | peasant backend | requests session detail | WebSocket |
| 3 | developer | peasant web | reviews redaction and gives consent | browser |
| 4 | peasant web | peasant backend | requests publication | HTTP |
| 5 | peasant backend | village backend | publishes the redacted session | HTTPS, schema wire |

```c4
Dynamic diagram: publish a session with /share

+-----------------------------+
| developer                   |
| [Person]                    |
+-----------------------------+
      |                     |
      | 1. opens /share     | 3. reviews redaction and
      | (browser, HTTP)     | gives consent (browser)
      v                     v
+-----------------------------+
| peasant web                 |
| [Container: Next.js 15]     |
+-----------------------------+
      |                     |
      | 2. requests session | 4. requests publication
      | detail (WebSocket)  | (HTTP)
      v                     v
+-----------------------------+
| peasant backend             |
| [Container: Go]             |
+-----------------------------+
              |
              | 5. publishes the redacted session (HTTPS, schema wire)
              v
+-----------------------------+
| village backend             |
| [Container: Go]             |
+-----------------------------+

Key:
  Solid box = element. [Type] = C4 abstraction. Numbered arrow = one interaction, in order.
  Read as "source, N. label (technology), target".
```

## Make your first contribution

1. Run `scripts/doctor` from the polyrepo root.
2. Run `scripts/provision-all` if the repository worktrees do not exist yet.
3. Choose the repository from the responsibility table above.
4. Read that repository's `AGENTS.md`, `CONTRIBUTING.md`, and test guide before editing.
5. Work in a feature worktree. Do not commit to a repository host's dummy branch.
6. Run the repository's required checks from its documented directory.
7. Open one pull request for the complete user-visible change.

When a change crosses repositories, start at the shared source of truth. Publish a schema or
redaction module version before consumer repositories update their pins. Put transcript rendering
changes in fairtrade before Peasant or Village adopts them.

## Sources and update rule

This guide was derived from the workspace `AGENTS.md`, the repository-local guides, current module
and package manifests, `village/develop/docker-compose.yml`, and
`village/develop/docs/railway-cloudflare-r2-activation.md`. Re-read those files before changing a
diagram. When code and a diagram disagree, the diagram is wrong.
