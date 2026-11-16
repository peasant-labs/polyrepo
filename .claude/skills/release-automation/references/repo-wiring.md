# Repo wiring

A repo releases through the shared tool when it carries the config, the policy,
and the three workflows below. Derive the current adopters instead of assuming
them:

```sh
rg -l 'release-intent|release-batch|release-queue.policy' /path/to/repo/.github
```

## Files

| File | Purpose |
|---|---|
| `.github/release-intent.yaml` | The release config. |
| `.github/release-queue.policy.yml` | The queue contract. |
| `.github/workflows/title-guard.yml` | Title and protected-path gate on every PR and merge-group build. |
| `.github/workflows/release-batch.yml` | Serialized `plan` / `verify` / `release` run. |
| `.github/workflows/cut-release.yml` | Forced-release dispatch. |
| `.github/workflows/release.yml` | Tag-triggered GitHub Release. |
| `.github/workflows/npm-publish.yml` | Tag-triggered npm publish, for an npm package. |

## Configuration

`.github/release-intent.yaml`:

```yaml
releases: true
tag_prefix: v                  # the text that opens release tags
automation_author: app/peasant-labs-releaser
changelog: CHANGELOG.md
version_files:                 # empty when the tag is the only version
  - {path: package.json, field: version}
protected_paths: []            # whole files only the release PR may write
surfaces: {}                   # spec surfaces, schema only
bot_branches:
  release: automation/release
  cut-release: automation/cut-release
  vendor-hash: automation/vendor-hash   # only repos that carry one
```

A repo with `releases: false` accepts no bracket or `!`. The shared config still
requires a tag prefix, automation author, and changelog path; they are inert
while releases are off.

`.github/release-queue.policy.yml`:

```yaml
queue:
  required:
    - {context: merge-gate, workflow: tests.yml, job: merge-gate, aggregator: true}
    - {context: title-guard, workflow: title-guard.yml, job: title-guard, guard: true}
  release_job:
    workflow: release-batch.yml
    job: release
    pre_tag_steps: []          # step ids; schema names its two contract steps
  bot_jobs:
    - {workflow: cut-release.yml, job: cut, kind: cut-release}
```

The `required` entries must equal the queue ruleset's required contexts. The
policy is read by both `check-workflows` and the workflows themselves.

## Workflow shape

- `title-guard.yml` runs on `pull_request` (opened, edited, synchronize,
  reopened) and `merge_group` with no early exit. It runs `check-config`,
  `check-workflows`, and `check-title` against the live title, author, and SHAs
  read from the API. On the release PR it also runs `release-pr --check`.
- `release-batch.yml` has three jobs:
  - `plan`, no App credential: builds the tool, plans, prepares the tag and the
    release commit, reads the queue, judges the hold rule, and uploads bundles.
  - `verify`, no App credential: independently recomputes the plan, binds the
    release source to the current default-branch tip, and verifies the bundles.
  - `release`, with the App token: mints the token, fetches bundles, pushes the
    tag or bot branch, and opens/updates/arms/holds/closes the release PR. It
    runs only pinned allowed actions, bundle fetches, and one `git` or `gh`
    command per step.
- `cut-release.yml` has `prepare` (no credential) and `cut` (App token). It is
  dispatch-only and writes only while tag mode is on.
- `release.yml` is the tag-triggered GitHub Release. It verifies the tag with
  `release-intent verify-tag` before publishing, and extracts the changelog
  section for the notes.
- `npm-publish.yml`, when present, also verifies the tag and publishes through
  npm Trusted Publishing (OIDC). No npm token is stored.

Credential jobs run on a literal GitHub-hosted runner, never the runner router:
a hosted runner is a fresh machine per job. Every checkout sets
`persist-credentials: false`. Every workflow and job declares read-only
permissions except the job that publishes the release or package.

## Operator steps

1. Install the releaser GitHub App on the repository with Contents write.
2. Set the Actions secret `PEASANT_RELEASER_APP_PRIVATE_KEY` and the repository
   variable `PEASANT_RELEASER_CLIENT_ID` (the client id is public; the private
   key is not).
3. Set `squash_merge_commit_title = PR_TITLE`; turning on `allow_auto_merge` is
   needed for a releasing repo (the release PR, the cut PR, and any vendor-hash
   PR arm themselves).
4. Create the queue ruleset on the exact default branch, compared with the
   policy file: `SQUASH`/`ALLGREEN`, min 2 entries, 5-minute wait, max 5, 3
   group builds, and the repo's check timeout. Read the required contexts back
   with `gh api repos/<owner>/<repo>/rules/branches/<branch>`.
5. Create or keep a tag ruleset that lets only the releaser App create release
   tags; keep deletion and non-fast-forward blocked.
6. Run a plan-only release batch with `RELEASE_BATCH_MODE` unset, inspect the
   range base, and read back that no branch, PR, or tag was written. Then set
   `RELEASE_BATCH_MODE=tag`.

## Checks before declaring a repo adopted

```sh
release-intent check-config --config .github/release-intent.yaml
release-intent check-workflows --policy .github/release-queue.policy.yml --dir .github/workflows
release-intent check-workflows --policy .github/release-queue.policy.yml --dir .github/workflows --print-required
actionlint .github/workflows/*.yml
```

`check-workflows` scans **every** workflow in the directory, not only the
required contexts. A workflow that mints an App token or pushes a ref outside
the listed release/bot jobs fails, even if it is not a queue check. The full
command is the gate; the `--print-required` form is for comparing contexts and
does not replace it.

If the repo has a `go.work`, build the pinned tool with `GOWORK=off`; otherwise
`go build` refuses because the tool module is not in the workspace.

## Reference adoptions

Fairtrade and redact are the two merged reference adoptions; their workflow
files are the shape to copy. A queue-only repo sets `releases: false` and omits
the release job. Always read the repo's own config and policy rather than
copying a sibling's values.
