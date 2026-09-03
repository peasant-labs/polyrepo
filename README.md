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
  && scripts/provision-all
```

## Toolchain

The scripts above need only git. To build and test the repositories you
need these tools. Install them natively, or take all of them from the
optional dev shell in the next section.

| tool | version | install |
|---|---|---|
| Go | 1.26 (the modules require at least 1.25) | https://go.dev/dl/ or your package manager |
| Node | 26 | https://nodejs.org/ or a version manager such as `fnm` or `nvm` |
| pnpm | 11.24.0 | `npm install -g pnpm@11.24.0` |

Every JavaScript repository pins the same pnpm version in the
`packageManager` field of `package.json`. Install that version once with
npm. Corepack is optional on Node 25 and later. If you use corepack,
install it first, then enable it:

```sh
npm install -g corepack && corepack enable
```

Check your tools:

```sh
go version && node --version && pnpm --version
```

## External contributors: install the tools on your OS

You do not need Nix for this path. (The core team uses the dev shell
instead; see the next section.) Run the installer from the polyrepo
checkout on macOS or Linux:

```sh
scripts/install-toolchain
```

The script shows this plan and asks before it makes changes. The block
below is an explicit summary of its Bash commands. Run the script
above instead: it also detects the OS and CPU, selects the newest Go
1.26 patch, verifies its checksum, uses a temporary directory, and
handles failures.

```sh
# Resolve the newest Go 1.26 patch from go.dev/dl.
GO_METADATA="$(curl -fsSL 'https://go.dev/dl/?mode=json&include=all')"
GO_VERSION="$(
  printf '%s\n' "$GO_METADATA" |
    sed -n -E 's/.*"version": "go(1\.26\.[0-9]+)".*/\1/p' |
    head -n 1
)"
GO_OS=linux    # The script also supports darwin.
GO_ARCH=amd64 # The script also supports arm64.
GO_ASSET="go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz"
GO_SHA256="$(
  printf '%s\n' "$GO_METADATA" | awk -v asset="$GO_ASSET" '
    $0 ~ "\"filename\": \"" asset "\"" { found = 1; next }
    found && !printed && /"sha256":/ {
      sub(/^.*"sha256": "/, ""); sub(/".*$/, ""); print; printed = 1
    }
  '
)"

# Download the selected SDK. The script reads its checksum from the
# same go.dev/dl metadata that supplied GO_VERSION.
curl -fsSL \
  "https://go.dev/dl/${GO_ASSET}" -o "$GO_ASSET"

# Verify the download, then install it into a versioned user directory.
printf '%s  %s\n' "$GO_SHA256" \
  "$GO_ASSET" | sha256sum --check -
mkdir -p "$HOME/go/${GO_VERSION}"
tar -C "$HOME/go/${GO_VERSION}" --strip-components=1 \
  -xzf "$GO_ASSET"
export PATH="$HOME/go/${GO_VERSION}/bin:$PATH"

# Install fnm without editing a shell profile, then install Node and pnpm.
curl -fsSL https://fnm.vercel.app/install -o fnm-install
bash fnm-install --skip-shell
FNM_BIN="$HOME/.local/share/fnm/fnm"
eval "$("$FNM_BIN" env --shell bash)"
"$FNM_BIN" install 26
"$FNM_BIN" use 26
npm install -g pnpm@11.24.0
```

## Core team: the dev shell

The core team does not install the tools natively (see the section
above). `flake.nix` gives one dev shell with the toolchain for every
repository (Go, Node, pnpm, linters, cloud CLIs). You do not need it to
clone or sync. To use it, install Nix and direnv, then trust `.envrc`.
home-manager is not expected. Open a new shell after each block.

```sh
# The Determinate installer sets up multi-user Nix.
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

```sh
# direnv loads and unloads the environment that .envrc defines.
# nix-direnv caches the dev shell and keeps it safe from garbage
# collection. These two are the only profile installs you need.
nix profile install nixpkgs#direnv
nix profile install nixpkgs#nix-direnv

# Wire nix-direnv into direnv: direnv auto-loads every file in lib/.
mkdir -p ~/.config/direnv/lib
ln -s ~/.nix-profile/share/nix-direnv/direnvrc ~/.config/direnv/lib/nix-direnv.sh
```

```sh
# Hook direnv into your shell so it loads .envrc on every directory
# change. Add the line for your shell, or both.
echo 'eval "$(direnv hook zsh)"'  >> ~/.zshrc
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
```

```sh
cd polyrepo && direnv allow
```

After this, `cd polyrepo` enters the dev shell by itself, and
nix-direnv caches the entry.

macOS ships bash 3.2, too old for nix-direnv, which needs bash 4.4 or
newer. Installing direnv through Nix or Homebrew works around this.

## What the steps do

1. `git clone` gets this repository.
2. `scripts/provision-all` clones each repository named in `repos.txt`
   at the current remote state and sets up its worktrees.
3. `direnv allow` (optional) trusts `.envrc`, which loads the dev shell
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

Run `scripts/sync-all` to fast-forward the default-branch worktree
(`develop` or `main`, as set on the remote) of every repository. Other
worktrees are not touched; update a feature worktree by hand with
`git pull` inside it. A fresh provision is already current, so there is
no need to run this right after `scripts/provision-all`.

Run `scripts/doctor` to check that your machine holds the tools for one
of the two paths: git plus the native toolchain (go, node, pnpm), or
git plus the Nix trio (nix, direnv, nix-direnv).

## Add a repository

1. Add a line to `repos.txt`: `<url> <dir>`.
2. Run `scripts/provision-all`.
