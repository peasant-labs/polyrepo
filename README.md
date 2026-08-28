# polyrepo

This repository holds the tools that a developer uses to check out the
peasant-labs repositories. It does not hold any product code.

## Quick start

You need git and an SSH key that is registered on GitHub. Nothing else.
Run this one command. It clones this repository, then clones the six
peasant-labs repositories into the `polyrepo` directory. It is safe to
run again.

```sh
git clone git@github.com:peasant-labs/polyrepo.git \
  && cd polyrepo \
  && scripts/provision-all \
  && scripts/sync-all
```

## Optional: the dev shell

`flake.nix` gives one dev shell with the toolchain for every repository
(Go, Node, pnpm, linters, cloud CLIs). You do not need it to clone or
sync. To use it, install Nix and direnv, then trust `.envrc`. Open a new
shell after each block.

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

```sh
nix profile install nixpkgs#direnv
echo 'eval "$(direnv hook zsh)"'  >> ~/.zshrc
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
```

```sh
cd polyrepo && direnv allow
```

After this, `cd polyrepo` enters the dev shell by itself. Optional:
add nix-direnv to cache the shell, so entering the directory is faster.

## What the steps do

1. `git clone` gets this repository.
2. `scripts/provision-all` clones each repository named in `repos.txt`
   and sets up its worktrees.
3. `scripts/sync-all` fast-forwards the default-branch worktree of each
   repository (`develop` or `main`, as set on the remote). Other
   worktrees are not touched.
4. `direnv allow` (optional) trusts `.envrc`, which loads the dev shell
   from `flake.nix` each time you enter the directory.

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
