# Design: the prompts behind a pull request

**Status:** design, approved in conversation on 2026-09-06, not yet planned or built.
**Scope:** a cross-repository change to `schema`, `peasant`, `village`, and
`fairtrade-design-system`, plus one human step on the GitHub App registration.

## Summary

A pull request today shows the code an agent produced. It does not show what the
author asked for. Reviewers are increasingly reviewing agent output with other
agents, and the one thing neither agent can see is the author's intent.

This design lets a pull request carry the prompts that produced it. Anyone with
write access clicks "Attach prompts" on the PR, or comments `/peasant attach`.
Village verifies that the click came from the PR author, finds the author's
sessions for that branch, and posts a digest: the skills and plugins the author
invoked, then the chain of human prompts in order, each anchored to the commits
it preceded. The digest links to the full transcripts on Village.

No new upload path is introduced, and no upload happens because of a click.
Uploading stays governed by the existing consent paths in Peasant: the share
wizard, or a per-repository upload hook the author installed. The upload gains
one structured field, the name of each skill invoked, which the turn text
already carried. Attaching adds one new consent, scoped to one PR: the author's
identity-verified click widens who may read the digest and the transcripts
behind it.

The point, beyond review quality, is adoption. A team gets something concrete
back for recording sessions, and the artifact it gets back is a reviewed,
redacted, commit-linked transcript. That is exactly the artifact the commons
needs. Contributing it to a collective becomes a second, optional step instead of
the whole ask.

## Goals

- Let a reviewer see how a PR was prompted, in the PR, with one click by the
  author.
- Keep the author's prompts private until the author acts, and make the act
  reversible.
- Reuse what exists: session-to-commit associations, the Village GitHub App
  client, linked repositories, the upload hooks, redaction, visibility, and the
  shared transcript viewer.
- Produce a digest that stays readable when a branch has many sessions and
  hundreds of prompts.

## Non-goals

- Scoring or grading prompts. The local scorecard stays off the PR surface.
- Pulling PR review comments back into transcripts as annotations. This is the
  most valuable later phase and is listed under deferred work.
- Forges other than GitHub.
- Any new upload path, or any change to when a Peasant upload happens. The one
  addition to upload contents is the structured skill invocation described
  under the schema changes.

## What exists today

| Capability | Where | State |
|---|---|---|
| Session-to-commit associations with durable IDs, on the publish wire | `schema.GitContext.Commits`, `GitContext.Associations`; `peasant/internal/ingest` | shipped |
| Per-transcript commit SHAs persisted and served | Village migration `020_transcript_commits`; `GET /api/v1/transcripts/{id}/commits` | shipped |
| GitHub App client: App JWT, installation tokens, repository access check, commit listing | `village/backend/internal/github` | shipped, read-only, config-gated |
| Collectives link GitHub repositories and cache their commits | migrations `021_collective_repositories`, `022_repository_commits`; `/api/v1/groups/{id}/repositories/...` | shipped |
| Collectives declare a linked GitHub org; users carry their GitHub orgs | `groups.linked_github_org`; migration `005_github_org_affiliations` | shipped |
| Numeric GitHub identity per user | `users.provider`, `users.provider_user_id`, legacy `users.github_id` | shipped |
| Opt-in per-repository upload hooks running a non-interactive push | `peasant village hooks install --event post-commit\|pre-push`; `peasant/docs/NETWORK.md` section 6 | shipped, ratified as a consent step |
| Skill and slash-command invocation parsing | `peasant/internal/ingest` (`parseSkillInvocation`, OpenCode `tool=skill`); local table `session_commands` | shipped, local only |
| Human-typed versus injected classification | `peasant/internal/sessionorigin`; `isSystemInjectedContent` | shipped |
| Transcript visibility private, shared, public; share to a collective | Village `POST /api/v1/transcripts/{id}/share` | shipped |
| Shared transcript viewer | `@peasant-labs/fairtrade` | shipped |

Three gaps decide the shape of the work:

1. Skill invocations are not on the published wire. `TurnDetail` has no command
   field, so Village cannot build the skills header from stored transcripts.
2. The GitHub App is read-only and has no webhook receiver. Both were deliberate
   in the repository-linking design. Posting to a PR needs write scope and a
   webhook.
3. Commit detection is coarse. A session is matched to commits within a
   three-day window on either side of the session, filtered by author email,
   gated on any `git commit` text appearing in the transcript. It over-attaches.

## User experience

### The author, private repository

1. The author works on a branch with an agent. Peasant ingests the sessions.
2. The author pushes. If the repository has an upload hook, the sessions are
   already in Village, private, before the PR exists.
3. The author opens the PR. The App posts a neutral check named `peasant /
   prompts` reading "no prompts attached", with an **Attach prompts** button.
4. The author clicks. Within seconds the check turns green, and one comment
   appears with the digest and a link to the full chain on Village.
5. Later pushes update the same comment in place. New sessions on the branch are
   picked up on the next click, or automatically if the author already attached
   and the new sessions arrive by hook.

No local prompt, no wizard. The click is the consent, and it is accepted only
because Village can prove who clicked.

### The reviewer

A reviewer clicks the same button or comments `/peasant attach`. Village records
a request. The check reads "a reviewer asked for prompts; the author can attach
with one click." The author's click then completes the attachment. A reviewer can
never expose an author's prompts.

### Public repositories

A comment on a public PR is world-readable and search-indexed, and the
transcripts behind it would have to become public too. On a public repository
the author's click therefore produces a **preview** rather than a post. The check
reads "preview ready" and links to a page on Village, where the author is already
signed in through GitHub, showing exactly what will be posted. One confirm there
posts it. The collective that owns the linked repository may switch this off.

Any user may turn the preview on for every repository with a personal setting,
`preview before attaching`. Default off.

### Detaching

The check carries a **Detach** button, and `/peasant detach` does the same. Only
the author's click is honoured. Detaching deletes the comment, sets the check
back to "no prompts attached", removes the PR link, and restores each
transcript's previous visibility. Deleted GitHub comments leave no visible
history. Notification emails already sent are the residual exposure, the same as
for any comment.

### Without a hook

If the author has not installed an upload hook, the click still lands. Village
finds no matching transcripts and the check reads "waiting for your machine: run
`peasant village push` in this repository, or install an upload hook." The
request is durable. When a matching transcript is published, by hand or by hook,
Village completes the attachment without a second click. `peasant village push`
prints a hint when a request is waiting for the repository being pushed.

### What the comment looks like

```
peasant · prompts behind #42
3 sessions · 27 prompts · 9 of 9 commits · claude-code · standard redaction

skills and plugins
  /superpowers:brainstorming  /superpowers:writing-plans  context7

prompts
   1. add a github check that posts the prompts behind a PR, skills…   → a1b2c3d
   2. it should be similar to how on PRs now you can request a rev…
      ↳ /superpowers:brainstorming
   3. …
  10. …

▸ show 17 more prompts
view all 27 on village · detach
```

The names and text above are illustrative and do not refer to any real
repository.

## The digest

### What counts as a prompt

A prompt is a user-role turn that a person typed. Peasant already decides this at
ingest: injected harness text, task notifications, system reminders, skill
bodies, and built-in slash commands are not prompts. Skill invocations are not
prompts either. They are recorded separately and appear in the digest as
markers.

### Ordering

Items are ordered by timestamp across every attached session. Four item kinds
appear in the chain:

| Kind | Rendering | Link target |
|---|---|---|
| session boundary | `session 2 · 2026-09-06 14:02 · 9 prompts · 3 commits` | the transcript on Village |
| prompt | numbered, first line of the prompt cut at 120 characters | that turn in the Village viewer |
| skill marker | `↳ /name args` indented under the preceding prompt | the same turn |
| commit anchor | `→ a1b2c3d` on the last prompt before the commit's author time | the commit on GitHub |

The header lists the distinct skills and plugins across all sessions. The chain
shows each invocation where it happened, because the order is what a reviewer is
judging.

### Tiers and budgets

The comment is a summary that points at the artifact. Three tiers, each with a
fixed budget, each linking to the next.

| Tier | Inline prompts | Collapsed prompts | Hard cap |
|---|---|---|---|
| PR comment | first 10 | the rest, in a native collapsed block, until the cap | 20,000 characters |
| check run output | first 25 | the rest, until the cap | 60,000 characters, under GitHub's limit |
| Village PR page | all | none | none |

The collapse rule is deterministic. Fill the inline set in chronological order.
Put the remainder in the collapsed block in order. When the next item would cross
the cap, replace every remaining session with a single boundary line stating how
many prompts it holds and linking to it on Village. Every session therefore keeps
a visible boundary in every tier, and a reviewer always sees where each sitting
began.

Individual prompts are cut at one line in the comment and check run. The Village
page shows them whole. Each cut line links to the turn it came from.

### One comment, edited in place

One sticky comment per PR. Each push edits it. A new comment is never posted for
a push. The check run is per head SHA, as GitHub requires, and carries the
larger digest in its output.

## Architecture

### Where each piece lives

| Repository | Adds |
|---|---|
| `schema` | `CommandInvocation` on `TurnDetail`; `PromptDigest` and its item types; `PullRequestAttachment` and its state enum; the new Village routes on the Village OpenAPI; version bumps |
| `peasant` | emits `CommandInvocation` from `session_commands` on the wire; branch-aware commit association; a hint in `peasant village push` when a request is waiting |
| `village` | webhook receiver; attachment tables and state machine; transcript matching; digest computation; GitHub Markdown renderer; comment and check run posting; preview, confirm, and detach routes; PR page in the frontend; user setting |
| `fairtrade-design-system` | `PromptDigest` component rendering the schema type, used by the Village PR page |

Village computes the digest server-side from the transcripts it holds. It does
not ask the author's machine for anything. This is why skill invocations must be
on the published wire.

### Sequence: attach on a hooked private repository

```
author            GitHub                 Village                      GitHub API
  |  git push  ->  (hook: peasant village push, private)  ->  transcript stored
  |  open PR  ->   pull_request.opened  ->  webhook
  |                                          create check "no prompts attached"  ->
  |  click Attach ->  check_run.requested_action  ->  webhook
  |                                          verify sender == PR author
  |                                          resolve author -> Village user
  |                                          match transcripts (remote, branch, SHAs)
  |                                          compute digest, store attachment
  |                                          share transcripts with the collective
  |                                          update check (success), post comment  ->
```

### Sequence: attach with no transcripts yet

The click is verified and the attachment is stored in state `waiting`. The check
explains what to run. When the author's publish arrives, the publish handler
looks up `waiting` and `attached` attachments for that user whose repository
matches the transcript's remote and matches the transcript against them. A
`waiting` attachment that gains a transcript completes. An `attached` attachment
that gains a transcript has its digest recomputed and its comment and check
updated. This second case is how a hooked repository keeps the digest current
without another click.

### Identity verification

Webhook deliveries are authenticated with the HMAC in `X-Hub-Signature-256`
against `GITHUB_APP_WEBHOOK_SECRET`. Inside a verified delivery, `sender.id` and
`pull_request.user.id` are numeric GitHub user ids asserted by GitHub. Village
resolves a sender to a user with `provider = 'github'` and `provider_user_id =
sender.id`. Logins are never used for identity. They are renamed and reused.

Users who signed in to Village through another provider have no GitHub identity.
For them the check reads "link your GitHub account on Village", and nothing else
happens.

Who may do what:

| Actor | Attach button or `/peasant attach` | Detach |
|---|---|---|
| PR author, resolved to a Village user | attaches, or opens a preview on a public repo | detaches |
| repository owner, member, or collaborator | records a request for the author | ignored |
| anyone else, including on public repos | ignored | ignored |

The comment payload's `author_association` decides the second row.

### Matching transcripts to a PR

Candidates are transcripts owned by the resolved author whose normalized remote
matches the PR's base repository or, for a fork PR, its head repository. Remote
normalization is the rule Village already applies to group transcripts by
repository. A candidate is attached when either holds:

- its recorded branch equals the PR head ref, or
- any of its persisted commit SHAs is a prefix of a commit in the PR, fetched
  through the App with `GET /repos/{owner}/{name}/pulls/{number}/commits`.

Pulled transcripts are never candidates. A transcript may be attached to more
than one PR, since one sitting can produce two branches. Attached transcripts
are ordered by session start.

### Visibility

Attaching widens who may read. For a private repository, each attached
transcript is shared with the collective that linked the repository, through the
existing share path. Because the collective's owner opted in by linking the
repository, the share opens approved rather than pending. For a public
repository, each attached transcript becomes public. A transcript that is already
public is left alone. The previous visibility is recorded per transcript so that
detaching restores it exactly.

Readers of the PR who are not members of the collective cannot open the full
transcript until they join. The comment footer says so. A PR-scoped read grant
for non-members is deferred; it would need a way to prove repository read access
to Village and is not required for the first release.

### Attachment state machine

| State | Meaning | Leaves on |
|---|---|---|
| `requested` | a non-author asked; nothing is exposed | author click → `attached`, `preview`, or `waiting` |
| `waiting` | author consented; no matching transcript exists yet | matching publish → `attached` or `preview`; detach → `detached` |
| `preview` | public repo or user setting; digest computed; the check text says "preview ready"; no comment posted and no visibility changed | confirm on Village → `attached`; detach → `detached` |
| `attached` | comment posted, check green, transcripts shared | detach → `detached`; new push or new matching publish → stays, digest recomputed, comment edited, check for the new head SHA marked success |
| `detached` | comment deleted, visibility restored | author click → `attached`, `preview`, or `waiting` |

A PR closing or merging leaves the attachment as is. The comment and check are
part of the PR's record.

### Check run semantics

The check is created on `pull_request.opened`, `reopened`, and `synchronize` for
repositories linked to a collective, when the collective's setting `post the
prompts check` is on. It is on by default, since linking the repository was
itself the opt-in.

The check's conclusion follows the collective's `prompts check mode`:

| Mode | No prompts attached | Prompts attached |
|---|---|---|
| `informational` (default) | `neutral` | `success` |
| `required` | `failure` | `success` |

`required` exists so an organization can make the check a branch-protection
requirement and thereby require prompts on every PR. The author still consents
per PR; the organization only decides whether an unattached PR can merge.

The check carries up to three action buttons, as GitHub allows: **Attach
prompts**, **Detach**, and **Refresh**. Refresh recomputes the digest for the
current head SHA and is useful when transcripts arrived after the last push.

## Data and contract changes

### schema

Additive, minor version bumps on the Types, Village API, and Peasant Local API
specifications. Follow the contract ceremony: the schema PR lands and is tagged
before either consumer re-pins.

- `TurnDetail.Command *CommandInvocation` with `Name` and `Args`. Populated for
  user-role turns that are skill or slash-command invocations. Before adding
  it, apply `docs/content-capability-negotiation.md` to decide whether a
  content-capability token is required for a consumer to rely on it.
- `PromptDigest` with `Header`, `Skills []SkillRef`, and `Items []DigestItem`.
  `DigestItem` carries a closed `Kind` (`session`, `prompt`, `skill`, `commit`),
  the transcript id, the turn index where relevant, the timestamp, the rendered
  text, and the commit SHA for commit anchors.
- `PullRequestAttachment` with repository owner and name, PR number, head SHA,
  state (closed enum above), author and requester identity as Village user ids,
  the comment and check run ids, and timestamps.
- `PullRequestAttachmentResponse` bundling the attachment, the digest, and the
  attached transcript summaries.
- Village routes:
  - `POST /api/v1/integrations/github/webhook`
  - `GET /api/v1/pulls/{owner}/{name}/{number}`
  - `POST /api/v1/pulls/{owner}/{name}/{number}/confirm`
  - `DELETE /api/v1/pulls/{owner}/{name}/{number}`
  - `GET /api/v1/users/me/prompt-requests`
  - the user setting `preview_before_attach` on the existing user update path
  - the collective settings `post_prompts_check` and `prompts_check_mode` on the
    existing collective update path

### village

Tables, following the numbered migration convention and the invariant document:

- `pull_request_attachments`: id, repository owner and name, GitHub repository
  id, PR number, head SHA, base and head remotes, author user id, requester
  GitHub id, state, comment id, check run id, computed digest as `jsonb`,
  timestamps for each transition.
- `pull_request_attachment_transcripts`: attachment id, transcript id,
  position, previous visibility.
- `users.preview_before_attach boolean not null default false`.
- `groups.post_prompts_check boolean not null default true` and
  `groups.prompts_check_mode` as a closed check constraint.
- `github_webhook_deliveries`: delivery id, received at. Deliveries are
  idempotent on `X-GitHub-Delivery`.

Handlers:

- The webhook receiver verifies the HMAC, records the delivery id, and
  dispatches `installation`, `pull_request`, `check_run`, and `issue_comment`
  events. Everything else is acknowledged and dropped.
- The publish handler gains one step after a successful store: match the new
  transcript against the owner's `waiting` and `attached` attachments for the
  same repository, completing or refreshing each one it matches.
- A `digest` package builds `PromptDigest` from stored transcripts and renders
  it to GitHub Markdown at a given budget. It reads transcripts through the
  existing decrypting content path and never logs their text.

GitHub App client additions, all through installation tokens: list PR commits,
create and update a check run, create, edit, and delete an issue comment.

The App registration changes, a human step:

| Setting | Value |
|---|---|
| Permissions | Metadata: read; Contents: read; Pull requests: read and write; Checks: read and write |
| Events | `installation`, `pull_request`, `check_run`, `issue_comment` |
| Webhook URL | `<BASE_URL>/api/v1/integrations/github/webhook` |
| Environment | existing `GITHUB_APP_ID` and `GITHUB_APP_PRIVATE_KEY`, plus `GITHUB_APP_WEBHOOK_SECRET` |

When the webhook secret is absent the receiver returns `501` and the check is
never created, matching how the existing repository endpoints behave when the
App is unconfigured.

Frontend: a `/pulls/{owner}/{name}/{number}` page that renders the digest with
the fairtrade component and, for the author, shows the confirm and detach
actions. A toggle for `preview before attaching` on the user settings surface.
Two toggles for the check on the collective settings page.

### peasant

- Project `session_commands` rows onto `TurnDetail.Command` through the single
  conversion path: `store.ListEntries()` → `api.EntriesToTurns()` →
  `api.SessionToDetail()`. The WebSocket viewer, the export, and the push body
  all gain the field together.
- Branch-aware commit association. When a session records a branch, a candidate
  commit must be reachable from that branch to be associated. The three-day
  window is unchanged and still applies when no branch was recorded. This is a
  precision change inside the existing detector, not a new detector.
- `peasant village push` asks `GET /api/v1/users/me/prompt-requests` when the
  user is logged in and prints one line naming any PR waiting for the repository
  being pushed. The request costs nothing when there is none. No new command.

Documentation: `docs/NETWORK.md` gains a row for the prompt-request lookup and a
short section on attaching, stating that attaching never uploads, and
`AGENTS.md` names the upload hook and PR attachment alongside the wizard as the
consented publication paths.

### fairtrade-design-system

A `PromptDigest` component under `/ui` that renders the schema type: header,
skills row, the chain with session boundaries, skill markers, and commit
anchors. It follows the design system's invariants for chrome, type, and
tokens. Village's PR page is its first consumer. It does not re-implement
transcript rendering; each item links into the existing viewer.

## Privacy and consent

What each action grants:

| Action | Who | Grants |
|---|---|---|
| installing an upload hook, or running the share wizard | the author, on their machine | upload to Village at the author's default visibility, as today |
| clicking Attach, or confirming a preview | the PR author, verified by GitHub identity | one PR's readers may read the digest; the attached transcripts are shared with the linked collective, or made public on a public repository |
| clicking Detach | the PR author | the grant above is withdrawn |

Redaction is unchanged. Transcripts are redacted at the standard level before
they leave the author's machine, and Village's secret scan at publish still
applies. The digest is computed from redacted turns. It contains no tool output,
only the author's own prompts and skill names. Prompts are the part of a
transcript most likely to contain something the author would not want a reviewer
to see, which is why public repositories preview by default and why Detach exists.

Village never logs digest text, prompt text, or comment bodies, consistent with
its existing rule against logging transcript content.

## Failure modes

| Situation | Behaviour |
|---|---|
| App not configured or webhook secret absent | no check is created; routes return `501` |
| repository not linked to any collective | no check; a comment command is ignored |
| author has no Village account, or signed in with another provider | check explains; nothing is exposed |
| author's Peasant is logged in as a different Village user | no transcripts match; check reads "waiting" and names the GitHub login that Peasant must be signed in as, which is the PR author's own and already visible on the PR |
| click from a non-author | request recorded; author notified through the check text |
| no matching transcripts | `waiting`; completed by a later publish |
| GitHub API error while posting | attachment stays in its previous state; the failure is retried on the next webhook delivery for that PR or on Refresh |
| digest exceeds every budget | per-session boundary lines with counts; the Village page holds everything |
| PR from a fork | matching uses the head repository's remote as well as the base |
| detach after notification emails were sent | comment deleted, visibility restored, emails cannot be recalled; stated in the docs |

## Testing

Each repository's own rules apply: fixtures in `testdata/*.yaml`, never inline
case tables; the race detector on every Go test; production handlers under test
with mocked dependencies; observable outcomes asserted.

- **schema:** fixtures for the new types and enums; zero-diff regeneration of
  the OpenAPI documents; the retired-spec guard stays green; the TypeScript
  package regenerates.
- **peasant:** a fixture family proving `Command` reaches the WebSocket
  payload, the export, and the push body through the single conversion path;
  branch-aware association fixtures covering reachable, unreachable, and
  branchless sessions; a handler test for the push hint against a mocked
  Village that returns zero, one, and several waiting requests.
- **village:** integration tests against PostgreSQL for the state machine,
  visibility recording and restoration, share approval on attach, and delivery
  idempotency; handler tests with an `httptest` GitHub for HMAC verification,
  identity resolution, `author_association` rules, and every API call the App
  makes; golden tests for the Markdown renderer at each budget over fixture
  transcripts that cover a short session, one long session, many sessions, a
  fork PR, and a transcript whose redaction placeholders must survive rendering.
- **fairtrade:** the component's mounted states captured in both themes per the
  repository's visual gate.
- **end to end:** Peasant's `make e2e` against the companion Village gains one
  journey: hook push, attach, digest present, detach, visibility restored.

## Delivery order

1. **schema.** Types, routes, version bumps. Land and tag.
2. **peasant.** Emit `Command`, branch-aware association, the push hint,
   documentation. Re-pin schema. This can ship before Village and is useful on
   its own, since it improves attribution precision for every consumer.
3. **Human step.** Re-register the App's permissions and events, provision the
   webhook secret in each environment.
4. **village.** Migrations, webhook, matching, digest, renderer, routes, the PR
   page, settings. Re-pin schema.
5. **fairtrade.** The digest component; Village adopts it on the PR page.

Steps 4 and 5 can proceed in parallel once step 1 has tagged.

## Deferred

- PR review comments flowing back to Village as annotations on the attached
  turns. This turns the commons into prompt, diff, and review triples and is the
  strongest reason to build the rest.
- A PR-scoped read grant so repository readers who are not collective members
  can open the full transcript.
- A banner in the Peasant terminal and web interfaces for waiting requests.
- Forges other than GitHub.
- Prompt scoring on the PR surface.

## Decisions recorded

- Opt-in per PR, triggered on GitHub. GitHub does not let an App be requested as
  a reviewer, so the affordance is a check-run button and a comment command.
- The click is the consent because Village can verify the clicker is the PR
  author through the numeric GitHub id both systems already hold.
- No new upload path. The upload hooks Peasant already ships put transcripts in
  Village before the PR exists; without a hook, the request waits for the
  author's next push.
- One click on private repositories. A preview confirm on public repositories,
  switchable by the collective, and available to any user for every repository.
- Visibility on attach maps to the collective that linked the repository, or to
  public on a public repository, and detaching restores the prior state.
- The digest is tiered. The comment is a summary with a fixed budget; the check
  run holds more; Village holds everything. One sticky comment, edited in place.
- No prompt scoring in the first release.
