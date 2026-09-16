---
name: issue-create-and-handle
description: Refine a peasant-labs request into one repository-specific GitHub issue, obtain explicit approval, create and assign it in the live repository, then hand it to issue-handler. Use when asked to file an issue and start work on it.
---

# Create, approve, assign, and handle a peasant-labs issue

Convert the user's request into one scoped issue in the repository that owns the behavior. Get explicit approval of the exact title and body before creation. Then assign the issue to the authenticated GitHub user and immediately follow `issue-handler` through merge.

## Preconditions

- `gh auth status` succeeds.
- The target repository can be identified from the ownership boundaries in root and repository `AGENTS.md` files.
- The user described a problem, requested behavior, or outcome.

Stop and ask if the owner repository, security disclosure path, permissions, or required cross-repo split is unclear.

## Resolve ownership

Use explicit live repository names for every `gh` command:

| Behavior | Owning repository |
|---|---|
| Peasant ingest, local store, CLI, TUI, local API implementation, mounted Peasant web | `peasant-labs/peasant` |
| Village registry, access control, discovery, PostgreSQL/S3, mounted Village frontend | `peasant-labs/village` |
| Shared Go/TypeScript wire, OpenAPI, enums, licenses, contract fixtures | `peasant-labs/schema` |
| Shared design tokens, transcript UI, graph engine, canonical transcript adapter | `peasant-labs/fairtrade-design-system` |
| Redaction rules and canonical redaction fixtures | `peasant-labs/redact` |

Do not file new runtime work in archived `transcript-browser`. Use Fairtrade for shared transcript and graph behavior.

A cross-repo outcome normally needs one issue per owning repository with explicit dependencies. Do not hide cross-repo work in one issue. Ask the user to approve the issue set before creating it.

## Workflow

1. **Inspect**
   - Read root `AGENTS.md` and the target repository's `AGENTS.md`, `CONTRIBUTING.md`, architecture/testing references, code, and nearest tests.
   - Search the exact live repository for duplicate open issues and PRs.
   - Search related owner repositories when the behavior crosses a contract or design-system boundary.
   - If an issue or PR already covers the request, report it and stop unless the user asks to refine or handle that existing item.

2. **Draft**
   - State current behavior with concrete source locations when known.
   - State user impact and the smallest owned scope.
   - Define observable acceptance criteria, production-path tests, fixture expectations, visual proof, and cross-repo order.
   - Use `[P1]`, `[P2]`, or `[P3]` in the title only when repository practice or the user supplies priority.
   - Peasant-labs issues use normal Markdown sections and explicit GitHub references.

Use this body shape:

```md
## Problem
...

## Scope
- ...

## Acceptance
- ...

## Diagram
```text
optional ASCII flow for multi-component behavior
```

## Blocked by / Blocks
- Blocked by: none | owner/repo#N
- Blocks: none | owner/repo#N

## Related
- owner/repo#N
```

For an epic, add a children table with priority, issue, and blocked-by columns, plus a definition of done. Use the `epic-composer` skill when the request is a set of follow-up epics or issues.

3. **Check boundaries**
   - Wire or API changes require a schema issue and release before consumer re-pins.
   - Shared UI or transcript rendering changes belong in Fairtrade before consumer adoption.
   - Database or governance changes name the migration, real-service integration tests, and invariant documentation requirements.
   - Interface changes require mounted-path tests and durable both-theme screenshots.
   - Combinatorial cases belong in named YAML fixture rows with required-name manifests, not count guards.

4. **Refine and approve**
   - Present the exact repository, proposed title, and complete issue body.
   - Ask for corrections or explicit approval.
   - Present a revised draft after any material change.
   - Do not create any issue until the user explicitly approves the current draft and, for a cross-repo set, the full issue set and dependency order.

5. **Create and assign**

```sh
GH_REPO="peasant-labs/<repo>"
ASSIGNEE=$(gh api user --jq .login)
ISSUE_URL=$(gh issue create -R "$GH_REPO" --title "<approved title>" \
  --body-file <approved-body-file> --assignee "$ASSIGNEE")
ISSUE_NUMBER=${ISSUE_URL##*/}
gh issue view "$ISSUE_NUMBER" -R "$GH_REPO" --json number,url,title,assignees
```

Create cross-repo issues in dependency order, then update their `Blocked by / Blocks` links if an issue number was not known during drafting. Do not add or change scope during this link update.

6. **Dispatch immediately**
   - Load and follow `issue-handler` with both `GH_REPO` and `ISSUE_NUMBER`.
   - The handler owns worktree creation, implementation, repository gates, PR review agents, CI, merge, default-branch sync, and cleanup.
   - Do not implement in a host or default-branch checkout before dispatch.

## Hard rules

1. Never create an issue without approval of its exact repository, title, and current body.
2. Never create a duplicate issue or PR.
3. Never use bare issue numbers when repository identity can be ambiguous.
4. Always assign the created issue to the authenticated GitHub login; never guess a username.
5. Preserve approved scope. New ambiguity requires refinement and approval.
6. Split work by repository ownership when contract, design-system, backend, or consumer changes have separate landing ceremonies.
7. Never place sensitive transcript content, tokens, credentials, personal paths, or private repository history in an issue.
8. After successful creation and assignment, invoke `issue-handler` immediately.
