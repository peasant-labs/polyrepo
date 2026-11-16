# Cutting a release by hand

Use a forced cut when there is nothing pending but a release is still wanted, or
to recover a release window. The release job is the only tag writer; a forced
cut is a request, never a manual tag.

## Preconditions

- `RELEASE_BATCH_MODE=tag` is set for the repository. While it is unset, the
  release batch plans only and writes nothing.
- The repository has the standing release PR flow and the `cut-release.yml`
  workflow.
- The repository setting `allow_auto_merge` is on for a releasing repo, so the
  cut PR can arm itself.
- The tag ruleset allows only the releaser App to create release tags.

## Preferred: the cut-release button

Run **Actions → cut-release → Run workflow** on the default branch and choose
`patch` or `minor`.

The workflow has two jobs:

1. `prepare`, no credential:
   - checks out the default branch;
   - creates one empty commit on `automation/cut-release` titled
     `release[<level>]: cut a release`;
   - bundles the branch;
   - finds an open cut PR: the same title is left open and updated, a different
     level is closed and recreated.
2. `cut`, with the releaser App token:
   - fetches the bundle and force-pushes `automation/cut-release`;
   - closes a stale cut PR if the level changed;
   - opens the cut PR and arms auto-merge.

The cut PR lands through the merge queue like any releasing PR. The release job
then plans from the landed cut commit and builds the release PR. The cut PR
itself must be **one empty commit**; a cut PR that changes any path fails
`release-content-scope`.

The cut title's level is a request. If the same window also holds a higher
level or a breaking change, the planner takes the strongest level; the cut does
not lower it.

## Alternative: an empty-commit PR

If the workflow dispatch is unavailable, open a PR whose only commit is empty:

```sh
git checkout -B automation/cut-release origin/<default>
git commit --allow-empty -m "release[patch]: cut a release"
git push -u origin automation/cut-release
gh pr create --base <default> --head automation/cut-release \
  --title "release[patch]: cut a release" \
  --body "Forced patch release. One empty commit; the release job builds the release PR."
```

Then arm auto-merge or let the maintainer enqueue it. Do not edit the
changelog, the version file, or any other path.

## Before the first cut in a new repo: the plan-only check

Do this once, before setting tag mode:

1. Leave `RELEASE_BATCH_MODE` unset.
2. Dispatch `release-batch.yml` on the default branch, or wait for the push
   run.
3. Inspect the step summary:
   - `action=none`;
   - the expected `range_base`;
   - no candidate or tag;
   - the version the plan would compute, if anything is pending.
4. Read back that nothing was written:

   ```sh
   git ls-remote --heads origin automation/release
   gh pr list --head automation/release --state all
   git ls-remote --tags origin '<prefix>*'
   ```

5. Only then set `RELEASE_BATCH_MODE=tag`.

A plan-only run mints no App token: the mint step is gated on tag mode.

## Recovery

- **The cut PR is stale or closed**: re-dispatch the button. It force-pushes the
  same bot branch and updates the PR.
- **The release PR is stale**: the next release-batch run rebuilds it. Dispatch
  `release-batch.yml` to force a run.
- **The release PR left the queue without landing**: the schedule or a dispatch
  re-arms it. A queued release PR is never dequeued.
- **The tag was pushed but the publish failed**: the tag burns its number. Fix
  forward with a new release; never move or delete the published tag.
- **A release PR is held**: a releasing PR is ahead in the queue. The hold is
  cleared by the next run after the queue drains; the release job never
  dequeues a queued release PR.
- **Two forced cuts in one window**: the tool folds identical cut requests and
  keeps the strongest level, but the released section is immutable. Avoid the
  double cut; if it happened, the duplicate cannot be edited out of the
  released changelog.

## What not to do

- Do not create, move, or delete a release tag by hand.
- Do not hand-write the changelog section or the version field.
- Do not push the default branch outside the merge queue.
- Do not bypass the cut PR with a direct tag push; the tag-triggered verify step
  will reject a tag the default branch does not reach, and a tag that does reach
  it still has no reviewed release content.
- Do not force a cut to “test” the release path. Use a plan-only run instead.
