# polyrepo

This repository holds the tools that a developer uses to check out the
peasant-labs repositories. It does not hold any product code.

## Prerequisites

- git.
- An SSH key registered on GitHub.
- Nix with flakes, installed through the Determinate installer.
- direnv, with nix-direnv.

## Steps

1. Clone this repository.
2. Run `direnv allow` in the repository root. This enters the dev shell.
3. Run `scripts/provision-all`. This clones each repository named in
   `repos.txt` and sets up its worktrees.
4. Run `scripts/sync-all`. This fast-forwards the default-branch
   worktree of each repository (`develop` or `main`, as set on the
   remote). Other worktrees are not touched.

## Repository host layout

Each repository gets its own host directory. A host holds an orphan
`__dummy__` branch, and one worktree for each branch that exists on the
remote (`main`, `develop`). Do not commit to `__dummy__` or push it.

```
peasant/
  .git/
  .gitignore
  main/
  develop/
```

## Repositories build alone

Each repository builds and tests on its own. No repository needs a
sibling checkout to build.

## Daily use

Run `scripts/sync-all` to bring the default-branch worktree of every
repository up to date with its remote. Update a feature worktree by
hand with `git pull` inside it.

## Add a repository

1. Add a line to `repos.txt`: `<url> <dir>`.
2. Run `scripts/provision-all`.
