{
  description = "peasant-labs polyrepo workspace dev shell";

  # One dev shell for every peasant-labs repository. The product repos have
  # their own flakes; this shell gives a new developer the shared toolchain
  # (Go, Node, pnpm, linters, contract gates, cloud CLIs) in one step.

  inputs = rec {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs = nixpkgs-unstable;
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-stable
    , nixpkgs-unstable
    , flake-utils
    , ...
    }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Tools from nixpkgs. shellcheck lints the scripts in this repo; the
        # rest serve the product repos (Go backends, pnpm frontends, OpenAPI
        # contract gates, GitHub Actions lint, terminal screenshots).
        devTools = with pkgs; [
          go_1_26
          gopls
          gotools
          go-tools
          delve
          ast-grep
          golangci-lint
          actionlint
          shellcheck
          vacuum-go
          charm-freeze
          pnpm
          typescript
          typescript-language-server
          nodejs_24
        ];

        # Contract-gate CLIs that nixpkgs does not package. Built from source.
        # vendorHash covers each tool's own third-party graph; recompute only on
        # a version bump (set to lib.fakeHash, `nix build .#<tool>`, copy `got:`).
        oasdiff = pkgs.buildGoModule {
          pname = "oasdiff";
          version = "1.19.1";
          src = pkgs.fetchFromGitHub {
            owner = "oasdiff";
            repo = "oasdiff";
            rev = "v1.19.1";
            hash = "sha256-fAMeFt3bmkxTXZuhGIlazga4lGnTCNIlXEST3NGnjFI=";
          };
          vendorHash = "sha256-+bRE23X6KL2Y7hdXPRxPu3WFPMWrjipINyf+5lJn0Q0=";
          subPackages = [ "." ];
          doCheck = false;
          env.CGO_ENABLED = 0;
          ldflags = [ "-s" "-w" ];
          meta = with pkgs.lib; {
            description = "OpenAPI diff and breaking-change detector";
            homepage = "https://github.com/oasdiff/oasdiff";
            license = licenses.asl20;
            mainProgram = "oasdiff";
          };
        };

        go-apidiff = pkgs.buildGoModule {
          pname = "go-apidiff";
          version = "0.8.3";
          src = pkgs.fetchFromGitHub {
            owner = "joelanford";
            repo = "go-apidiff";
            rev = "v0.8.3";
            hash = "sha256-qDx+vGmXFdFTMXHT6/5mbsGagvBixsxUkXmNg6dI/SE=";
          };
          vendorHash = "sha256-TEesxbzvlT9VeVujbPzfd6fSQZJMzf/9KoiWECrY7wk=";
          doCheck = false;
          env.CGO_ENABLED = 0;
          ldflags = [ "-s" "-w" ];
          meta = with pkgs.lib; {
            description = "Detect incompatible changes in a Go module's exported API across git refs";
            homepage = "https://github.com/joelanford/go-apidiff";
            license = licenses.asl20;
            mainProgram = "go-apidiff";
          };
        };

        contractGateTools = [ oasdiff go-apidiff ];
        cloudOpsTools = with pkgs; [ railway wrangler postgresql_18 jq curl coreutils openssl ];
      in
      {
        packages.oasdiff = oasdiff;
        packages.go-apidiff = go-apidiff;

        devShells.default = pkgs.mkShell {
          name = "polyrepo-dev";
          packages = devTools ++ contractGateTools ++ cloudOpsTools;
          shellHook = ''
            echo "peasant-labs polyrepo dev shell (go $(go version | cut -d' ' -f3), node $(node --version))"
            export CGO_ENABLED=1
            [ -f .envrc.local ] && source .envrc.local || true
          '';
        };
      });
}
