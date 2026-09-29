# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

- **Primary: the publishing developer.** They work with an AI coding agent on their own machine, mostly Claude Code, and also OpenCode, Cursor, Codex, and Gemini CLI. They want the session behind a change to be reviewable. From inside the agent session they run `/peasant` to open that session locally, review it, publish it (or update it) to one or more collectives, and open a pull request that links it.
- **Secondary: the pull-request reviewer.** They arrive from a GitHub pull request, through its `peasant / prompts` check or comment, and read on village the transcripts that produced the change.
- **Secondary: the collective owner.** They set up a collective for a whole company or for one team, with members, roles, and linked repositories and orgs, so that publishing and PR linking work without further setup.
- **Also: commons readers.** They browse public transcripts on village.

## Product Purpose

Peasant-labs turns private AI coding sessions into reviewable transcripts that are tied to Git history.

- **Peasant** is open source and local first. It records and indexes agent sessions, connects them to repositories and commits, and redacts sensitive content. It serves a local web view.
- **Village** is the hosted service. It stores published transcripts, enforces access per collective, and links transcripts to the pull requests whose changes they produced.

Success means two things:
- a reviewer can see the agent trace behind a PR's changes;
- a developer can publish the session they are reading in one action, from where they already are.

## Positioning

Peasant-labs shows the agent session that produced a code change, matched to the pull request by commit evidence. It is not a generic chat log. Redaction runs on the developer's machine before anything leaves it, and publication is always an explicit act of consent.

## Operating Context

- **Claude Code `/peasant`.** The command comes from the peasant-plugins plugin. It ingests the current session and opens it in the local web.
- **Local web.** It runs at `localhost:8690` and is served by the `peasant` binary.
- **CLI.**
  - `peasant kickstart` handles setup and project selection.
  - `peasant village login` and `peasant village push`.
  - The optional git hooks.
- **Village web.**
  - Sign-in, then claiming a handle.
  - The user's own transcripts.
  - Collectives, and their settings.
  - The transcript page and the PR prompts page.
- **GitHub.**
  - Village's GitHub App, installed by a collective owner.
  - On pull requests, the `peasant / prompts` check and a sticky comment.
- **Dogfooding.** The team publishes its own sessions as the first exemplars, so that new users see the creators using the product.

## Capabilities and Constraints

- **Terminology.**
  - A local recording is a *session*; a published copy is a *transcript*.
  - The one outward action is **publish**, which becomes **update** once a session has been published. These replace share, contribute, push, and submit in the UI.
  - A group on village is a *collective*.
- **Consent.** Nothing leaves the machine until the developer publishes. `/share` stays the canonical publish route, and there is no alternate `/push` route.
- **Redaction.**
  - The categories are secrets, pii, paths, and project. They render as `CREDENTIAL`, `PII`, `PATH`, and `INTERNAL`, from the engine's `Category.String()`.
  - `standard` is the only level offered.
  - Unknown categories fail closed.
- **Visibility.** A transcript is private, shared with collectives, or public.
- **Audience for this overhaul: collectives only.** Publishing from the local web shares a transcript with the collectives the developer picks. The public commons is hidden in the UI, not deleted. An update keeps the audience the transcript already has.
- **Licenses.** Only `CC0-1.0`, `CC-BY-4.0`, and `CC-BY-SA-4.0` are offered, and a granted license cannot be revoked. A license is asked for only when something becomes public, so the collectives-only flow does not ask for one.
- **PR linking.**
  - A PR author links transcripts by commenting `/peasant attach` on the pull request, then confirming the preview.
  - Automatic linking when a PR opens is a setting that is off by default.
  - Matching uses commit evidence: at least one recorded commit must be in the PR.
- **Collectives.**
  - Acceptance is open, verified only, or curated.
  - Data access is members only, contributors, or public.
  - The roles are owner, member, and contributor, and they are fixed today.
  - A collective can link many repositories but only one GitHub org today.
- **Selection.** The kickstart selection scopes discovery and lists only. It is not access control, and stored sessions stay reachable by deep link.
- **Sign-in.** It is GitHub only for now. The other providers are hidden, not deleted.
- **Overhaul constraints.**
  - Simplify by hiding surfaces in the frontends. Keep the backends.
  - Keep real earlier user flows reachable as deprecation candidates.
  - Wire-contract and database changes take the expensive path and are tried last.
- **Open decisions.**
  - Configurable role sets.
  - Several orgs per collective.
  - Connecting GitHub once for both local and village.

## Brand Commitments

- **Names.** The product names are peasant, village, and fairtrade.
- **Visual authority.** Visual decisions belong to the fairtrade design system (`@peasant-labs/fairtrade`; its `llm/DESIGN.md` and `llm/NEUROINCLUSIVE.md`). Both apps conform to it and never redefine its values.
- **Voice.** Plain, literal, and calm. UI chrome is lowercase and user content is never lowercased. Provider names lead with their brand mark. No AI-slop language.

## Evidence on Hand

- **Available.** The fairtrade in-use demo and its fixtures, and the team's own recorded sessions for dogfooding.
- **Not available.** No customer names, testimonials, usage numbers, or benchmarks exist. Do not invent them.

## Product Principles

1. **Local first, consent always.** Redact on the machine, show what will leave it, fail closed, and publish only on an explicit act.
2. **One action from where you are.** The session you are reading is the one you publish. The PR you open finds its transcripts.
3. **Git is the spine.** A transcript matters because it traces to commits and pull requests.
4. **Tell the truth about state.** Show whether a session is published, who can read it, and what an update changes.
5. **Hide, don't delete.** Simplify surfaces without breaking stored data, deep links, or flows people already use.

## Accessibility & Inclusion

Both themes meet WCAG AA, and fairtrade's neuroinclusive defaults apply:
- a 16px body floor;
- at most five primary actions per view;
- static-first motion;
- no meaning carried by color alone.
