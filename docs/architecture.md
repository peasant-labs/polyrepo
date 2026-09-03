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

## Shared contract and redaction components

Schema and redact are shared Go modules, not runtime systems. The build compiles them into both
backends. Schema owns serialized types, validators, generated specifications, closed enums, and
license identifiers. Redact owns categories, matching rules, canonical fixtures, and rule-set
versions. Each backend owns the policy and application behavior around those shared definitions.

### Peasant backend model

```c4
Component diagram: peasant backend shared modules

+== peasant backend [Container: Go] =============================================================+
|                                                                                                |
|  +-----------------------------+                                +-----------------------------+ |
|  | ingest pipeline             |-- applies rules (Go call) ---->| redaction engine            | |
|  | [Component: Go package]     |                                | [Component: Go module]      | |
|  | Reads agent records and     |                                | Classifies and transforms   | |
|  | materializes sessions.      |                                | sensitive transcript data.  | |
|  +-----------------------------+                                +-----------------------------+ |
|                                                                                                |
|  +-----------------------------+                                +-----------------------------+ |
|  | API and publication mapper  |-- builds payloads (Go call) -->| schema contract             | |
|  | [Component: Go package]     |                                | [Component: Go module]      | |
|  | Builds API payloads and     |                                | Supplies canonical wire     | |
|  | publish requests.           |                                | types and envelopes.        | |
|  +-----------------------------+                                +-----------------------------+ |
|                                                                                                |
+================================================================================================+

Key:
  Solid box = component. Double-line box = container boundary. [Type] = C4 abstraction.
  Arrow = one relationship, read as "source, label (technology), target".
```

| Name | Type | Technology | Description |
|---|---|---|---|
| ingest pipeline | Component | Go package | Reads agent records and materializes local sessions. |
| redaction engine | Component | Go module | Classifies and transforms sensitive transcript data. |
| API and publication mapper | Component | Go package | Builds local API payloads and Village publish requests. |
| schema contract | Component | Go module | Supplies canonical wire types and publish envelopes. |

| Source | Target | Intent | Technology |
|---|---|---|---|
| ingest pipeline | redaction engine | applies canonical redaction rules | Go call |
| API and publication mapper | schema contract | builds canonical payloads | Go call |

### Village backend model

```c4
Component diagram: village backend shared modules

+== village backend [Container: Go] =============================================================+
|                                                                                                |
|  +-----------------------------+                                +-----------------------------+ |
|  | publish and API handlers    |-- validates data (Go call) --->| schema contract             | |
|  | [Component: Go package]     |                                | [Component: Go module]      | |
|  | Validate requests and       |                                | Supplies the served spec    | |
|  | produce registry responses. |                                | and publish validator.      | |
|  +-----------------------------+                                +-----------------------------+ |
|                                                                                                |
|  +-----------------------------+                                +-----------------------------+ |
|  | title and content safety    |-- applies rules (Go call) ---->| redaction engine            | |
|  | [Component: Go package]     |                                | [Component: Go module]      | |
|  | Applies checks at Village   |                                | Supplies categories and     | |
|  | trust boundaries.           |                                | matching rules.             | |
|  +-----------------------------+                                +-----------------------------+ |
|                                                                                                |
+================================================================================================+

Key:
  Solid box = component. Double-line box = container boundary. [Type] = C4 abstraction.
  Arrow = one relationship, read as "source, label (technology), target".
```

| Name | Type | Technology | Description |
|---|---|---|---|
| publish and API handlers | Component | Go package | Validate requests and produce registry responses. |
| schema contract | Component | Go module | Supplies the served specification and publish validator. |
| title and content safety | Component | Go package | Applies safety checks at Village trust boundaries. |
| redaction engine | Component | Go module | Supplies canonical categories and matching rules. |

| Source | Target | Intent | Technology |
|---|---|---|---|
| publish and API handlers | schema contract | validates and maps contract data | Go call |
| title and content safety | redaction engine | applies canonical safety rules | Go call |

This split prevents drift. Village serves and enforces the same schema bytes from its pinned
module. Peasant and Village both derive accepted contract values from that module. Both backends
use the same redact package for semantic categories and rules, while each backend keeps its own
activation and access policy.

## System landscape

This view shows the people and runtime systems. It does not show repositories that contain only
libraries or development tools.

### Model

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

## Inside Peasant

Peasant runs on the developer's machine. Its backend owns ingestion and policy. Its web application
shows the resulting sessions. SQLite keeps the local record.

### Model

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

## Inside Village

Village is the hosted commons. Its frontend serves readers. Its backend validates publications,
enforces access rules, and splits metadata from transcript objects. Development uses PostgreSQL 16
and MinIO. Production uses Railway PostgreSQL and Cloudflare R2 through the same SQL and S3 APIs.

### Model

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

## What happens when a developer shares a session

This dynamic view shows runtime order. It is not a replacement for the static container views.
The schema module defines the wire used in step 5. The redact module supplies the rules used before
the developer consents. Fairtrade supplies the transcript and review components in Peasant web.

### Model

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

| Step | Source | Target | Intent | Technology |
|---|---|---|---|---|
| 1 | developer | peasant web | opens `/share` | browser, HTTP |
| 2 | peasant web | peasant backend | requests session detail | WebSocket |
| 3 | developer | peasant web | reviews redaction and gives consent | browser |
| 4 | peasant web | peasant backend | requests publication | HTTP |
| 5 | peasant backend | village backend | publishes the redacted session | HTTPS, schema wire |

## Version, tag, and release pipelines

A release starts with a pull request whose title is the version cut interface. The release-PR
workflow validates the title and maintainer authority before merge. After merge, the releaser
GitHub App pushes an annotated tag. The App token matters because a tag pushed with the default
workflow token does not start another GitHub Actions workflow. Tags are immutable. If a tag already
exists, the workflow stops and requires a new version.

The repositories share this ceremony, but they publish different artifacts:

| Repository | Release branch | Release PR title | Annotated tag | Version source | Published outputs |
|---|---|---|---|---|---|
| `schema` | `develop` | `release(vX.Y.Z[-rcN]): summary` | `vX.Y.Z[-rcN]` | PR title; npm manifest is stamped in CI only | GitHub contract assets and `@peasant-labs/schema` |
| `redact` | `main` | `release(vX.Y.Z[-rcN]): summary` | `vX.Y.Z[-rcN]` | PR title and tag | GitHub Release |
| `fairtrade-design-system` | `main` | `release(vX.Y.Z[-rcN]): summary` | `fairtrade-vX.Y.Z[-rcN]` | PR title must match committed `package.json` | GitHub Release and `@peasant-labs/fairtrade` |
| `peasant` | `develop` | `release(vX.Y.Z[-rcN]): summary` | `vX.Y.Z[-rcN]` | PR title and tag | GitHub Release, archives, checksums, deb, and rpm packages |
| `village` | `develop` | No release workflow | No release tag | Not applicable | Test CI only |

### Release PR to immutable tag

This interaction is the common control plane. Schema and Peasant also refresh and verify the Nix
vendor hash before the tag. Redact reruns `make release-check` on the merge commit. Fairtrade checks
that the merged `package.json` version matches the release title.

```c4
Dynamic diagram: release PR to immutable tag

+-----------------------------+
| maintainer                  |
| [Person]                    |
+-----------------------------+
              |
              | 1. opens a versioned release pull request (GitHub pull request)
              v
+-----------------------------+
| release PR workflow         |
| [Component: GitHub Actions] |
+-----------------------------+
              |
              | 2. validates title, authority, version, and gates (GitHub Actions)
              v
+-----------------------------+
| quality gates               |
| [Component: CI workflows]   |
+-----------------------------+

+-----------------------------+
| maintainer                  |
| [Person]                    |
+-----------------------------+
              |
              | 3. merges the release pull request (GitHub pull request)
              v
+-----------------------------+
| GitHub repository           |
| [Software System]           |
+-----------------------------+
              |
              | 4. sends the merged event (GitHub Actions event)
              v
+-----------------------------+
| release PR workflow         |
| [Component: GitHub Actions] |
+-----------------------------+
              |
              | 5. pushes a new annotated tag (GitHub App token, Git)
              v
+-----------------------------+
| GitHub repository           |
| [Software System]           |
+-----------------------------+
              |
              | 6. starts tag publication (GitHub Actions event)
              v
+-----------------------------+
| release workflow            |
| [Component: GitHub Actions] |
+-----------------------------+

Key:
  Solid box = element. [Type] = C4 abstraction. Numbered arrow = one interaction, in order.
  Read as "source, N. label (technology), target". Repeated boxes name the same element.
```

| Step | Source | Target | Intent | Technology |
|---|---|---|---|---|
| 1 | maintainer | release PR workflow | opens a versioned release pull request | GitHub pull request |
| 2 | release PR workflow | quality gates | validates title, authority, version, and repository gates | GitHub Actions |
| 3 | maintainer | GitHub repository | merges the approved release pull request | GitHub pull request |
| 4 | GitHub repository | release PR workflow | sends the merged event | GitHub Actions event |
| 5 | release PR workflow | GitHub repository | pushes a new annotated tag | GitHub App token, Git |
| 6 | GitHub repository | release workflow | starts tag publication | GitHub Actions event |

### Schema contract publication

Schema is a contract library. A tag does not build a server or CLI. It validates the immutable
contract, publishes generated contract files with a GitHub Release, and publishes the generated
TypeScript package to npm. Release candidates use the npm `next` tag. Final versions use `latest`.
The npm job stamps `typescript/package.json` only in its CI working copy, so the development
manifest stays private and uses its development version.

```c4
Dynamic diagram: schema tag publication

+-----------------------------+
| schema tag event            |
| [Component: Git tag event]  |
+-----------------------------+
              |
              | 1. parses and classifies the tag (GitHub Actions)
              v
+-----------------------------+
| release guard               |
| [Component: release-guard]  |
+-----------------------------+
              |
              | 2. verifies the vendored dependency hash (Nix)
              v
+-----------------------------+
| Nix hash gate               |
| [Component: GitHub Actions] |
+-----------------------------+
              |
              | 3. lints and compares the contract (vacuum, oasdiff, go-apidiff)
              v
+-----------------------------+
| contract gates              |
| [Component: GitHub Actions] |
+-----------------------------+
       |                                               |
       | 4. publishes contract assets                  | 5. publishes the package
       | (GitHub API)                                  | (pnpm, OIDC)
       v                                               v
+-----------------------------+                 +-----------------------------+
| GitHub Release              |                 | npm registry                |
| [Software System, external] |                 | [Software System, external] |
+-----------------------------+                 +-----------------------------+

Key:
  Solid box = element. [Type] = C4 abstraction. Numbered arrow = one interaction, in order.
  OIDC = OpenID Connect. Read as "source, N. label (technology), target".
```

| Step | Source | Target | Intent | Technology |
|---|---|---|---|---|
| 1 | schema tag event | release guard | parses and classifies the tag | GitHub Actions |
| 2 | release guard | Nix hash gate | verifies the vendored dependency hash | Nix |
| 3 | Nix hash gate | contract gates | lints and compares the published contract | vacuum, oasdiff, go-apidiff |
| 4 | contract gates | GitHub Release | publishes generated JSON and YAML assets | GitHub API |
| 5 | contract gates | npm registry | publishes `@peasant-labs/schema` with provenance | pnpm, OIDC |

### Redact module publication

Redact has the smallest release pipeline. The tag workflow verifies the exact tag commit, reruns
the release quality gate, and classifies the version. A final version also requires a successful
same-version release-candidate ancestor. It then creates a GitHub Release with generated notes.

```c4
Dynamic diagram: redact tag publication

+-----------------------------+
| redact tag event            |
| [Component: Git tag event]  |
+-----------------------------+
              |
              | 1. verifies the tag commit and module (GitHub Actions, Go)
              v
+-----------------------------+
| release quality gate        |
| [Component: make target]    |
+-----------------------------+
              |
              | 2. classifies the tag and checks ancestry (releaseguard, GitHub API)
              v
+-----------------------------+
| version guard               |
| [Component: Go command]     |
+-----------------------------+
              |
              | 3. publishes generated release notes (GitHub API)
              v
+-----------------------------+
| GitHub Release              |
| [Software System, external] |
+-----------------------------+

Key:
  Solid box = element. [Type] = C4 abstraction. Numbered arrow = one interaction, in order.
  Read as "source, N. label (technology), target".
```

| Step | Source | Target | Intent | Technology |
|---|---|---|---|---|
| 1 | redact tag event | release quality gate | verifies the tag commit and module | GitHub Actions, Go |
| 2 | release quality gate | version guard | classifies the tag and verifies final-release ancestry | releaseguard, GitHub API |
| 3 | version guard | GitHub Release | publishes generated release notes | GitHub API |

### Fairtrade package publication

Fairtrade uses one tag to start two independent workflows. The npm workflow verifies that the tag
matches `package.json`, runs the package gates through `prepack`, publishes with npm Trusted
Publishing, and checks the provenance result. The GitHub Release workflow parses the same tag,
extracts the matching `CHANGELOG.md` section, and creates or updates the release notes. One output
can fail without blocking the other.

```c4
Dynamic diagram: fairtrade tag publication

+-----------------------------+
| fairtrade tag event         |
| [Component: Git tag event]  |
+-----------------------------+
       |                                               |
       | 1. starts package validation                  | 4. starts release-note publication
       | (GitHub Actions)                              | (GitHub Actions)
       v                                               v
+-----------------------------+                 +-----------------------------+
| npm publish workflow        |                 | GitHub Release workflow     |
| [Component: GitHub Actions] |                 | [Component: GitHub Actions] |
+-----------------------------+                 +-----------------------------+
       |                                               |
       | 2. publishes the validated package            | 5. publishes the changelog section
       | (npm, OIDC)                                   | (GitHub API)
       v                                               v
+-----------------------------+                 +-----------------------------+
| npm registry                |                 | GitHub Release              |
| [Software System, external] |                 | [Software System, external] |
+-----------------------------+                 +-----------------------------+
       |
       | 3. reports the package attestation (npm registry API)
       v
+-----------------------------+
| provenance check            |
| [Component: GitHub Actions] |
+-----------------------------+

Key:
  Solid box = element. [Type] = C4 abstraction. Numbered arrow = one interaction, in order.
  OIDC = OpenID Connect. Read as "source, N. label (technology), target".
```

| Step | Source | Target | Intent | Technology |
|---|---|---|---|---|
| 1 | fairtrade tag event | npm publish workflow | starts package validation | GitHub Actions |
| 2 | npm publish workflow | npm registry | publishes the validated package | npm, OIDC |
| 3 | npm registry | provenance check | reports the package attestation | npm registry API |
| 4 | fairtrade tag event | GitHub Release workflow | starts release-note publication | GitHub Actions |
| 5 | GitHub Release workflow | GitHub Release | publishes the matching changelog section | GitHub API |

### Peasant product publication

Peasant publishes an installable product. Its tag workflow verifies the App actor and tag grammar,
checks the Nix vendor hash, runs full-stack and installed-package tests, builds the embedded web
application, and runs GoReleaser. Native amd64 and arm64 runners then download and verify the
published Linux archives. Release candidates also run the wider package-validation matrix for
Linux package formats, Homebrew, Nix, and macOS.

```c4
Dynamic diagram: peasant tag publication

+-----------------------------+
| peasant tag event           |
| [Component: Git tag event]  |
+-----------------------------+
              |
              | 1. verifies the App actor and classifies the tag
              | (GitHub Actions, release-guard)
              v
+-----------------------------+
| release guard               |
| [Component: release-guard]  |
+-----------------------------+
              |
              | 2. verifies the vendored dependency hash (Nix)
              v
+-----------------------------+
| Nix hash gate               |
| [Component: GitHub Actions] |
+-----------------------------+
              |
              | 3. runs full-stack and package tests (reusable workflows)
              v
+-----------------------------+
| release tests               |
| [Component: GitHub Actions] |
+-----------------------------+
              |
              | 4. builds the web app and artifacts (Node.js, pnpm, GoReleaser)
              v
+-----------------------------+
| GoReleaser                  |
| [Component: release tool]   |
+-----------------------------+
              |
              | 5. publishes archives and packages (GitHub API)
              v
+-----------------------------+
| GitHub Release              |
| [Software System, external] |
+-----------------------------+
              |
              | 6. supplies artifacts for native verification (HTTPS)
              v
+-----------------------------+
| native smoke tests          |
| [Component: GitHub Actions] |
+-----------------------------+

Key:
  Solid box = element. [Type] = C4 abstraction. Numbered arrow = one interaction, in order.
  Arrow = one ordered interaction. Read as "source, N. label (technology), target".
```

| Step | Source | Target | Intent | Technology |
|---|---|---|---|---|
| 1 | peasant tag event | release guard | verifies the App actor and classifies the tag | GitHub Actions, release-guard |
| 2 | release guard | Nix hash gate | verifies the vendored dependency hash | Nix |
| 3 | Nix hash gate | release tests | runs full-stack and installed-package tests | reusable GitHub Actions workflows |
| 4 | release tests | GoReleaser | builds the web application and release artifacts | Node.js, pnpm, GoReleaser |
| 5 | GoReleaser | GitHub Release | publishes archives, checksums, and packages | GitHub API |
| 6 | GitHub Release | native smoke tests | verifies static binaries and embedded versions | amd64 and arm64 Linux runners |

### Consumer update order

After Schema or Redact publishes a tag, consumer updates are separate pull requests. Peasant and
Village update the Go module pin. Their frontends update `@peasant-labs/schema` when the generated
TypeScript contract changes. Each consumer runs its own tests against the published module. A
consumer never merges against an unpublished local contract revision.

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
