# polyrepo

This repository holds the tools that a developer uses to check out the
peasant-labs repositories. It does not hold any product code.

## Quick start

You need git and an SSH key that is registered on GitHub. Then run the
three blocks below, one at a time. Each block is safe to run again.

1. Install Nix with flakes enabled (Linux, macOS, and WSL2). Open a new
   shell when it finishes.

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

2. Install direnv and hook it into your shell. Use the `.zshrc` line for
   zsh, or the `.bashrc` line for bash. Open a new shell when done.

```sh
nix profile install nixpkgs#direnv
echo 'eval "$(direnv hook zsh)"'  >> ~/.zshrc
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
```

3. Clone this repository and provision the workspace. This clones the
   six peasant-labs repositories into the `polyrepo` directory and
   enters the dev shell.

```sh
git clone git@github.com:peasant-labs/polyrepo.git \
  && cd polyrepo \
  && direnv allow \
  && nix develop --command scripts/provision-all \
  && nix develop --command scripts/sync-all
```

After this, `cd polyrepo` enters the dev shell by itself.

## Prerequisites

- git.
- An SSH key registered on GitHub.
- Nix with flakes (the Quick start installs it).
- direnv (the Quick start installs it). Optional: add nix-direnv to
  cache the dev shell, so entering the directory is faster.

## What the steps do

1. `git clone` gets this repository.
2. `direnv allow` trusts `.envrc`, which loads the dev shell from
   `flake.nix` each time you enter the directory.
3. `scripts/provision-all` clones each repository named in `repos.txt`
   and sets up its worktrees.
4. `scripts/sync-all` fast-forwards the default-branch worktree of each
   repository (`develop` or `main`, as set on the remote). Other
   worktrees are not touched.

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
