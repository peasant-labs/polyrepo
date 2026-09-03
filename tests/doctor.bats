#!/usr/bin/env bats
# doctor.bats - tests for scripts/doctor.
#
# Every test runs scripts/doctor with a hermetic PATH (only the stub
# bin directory) and a fake HOME, so the machine that runs the suite
# cannot leak its own tools into a verdict.

load 'helpers'

# make_stub <dir> <name> <output>
# Write one stub executable into <dir> that prints <output> on one
# line, whatever arguments it gets.
make_stub() {
  local dir="$1" name="$2" out="$3"
  {
    echo '#!/usr/bin/env bash'
    echo "printf '%s\\n' '${out}'"
  } > "${dir}/${name}"
  chmod +x "${dir}/${name}"
}

# run_doctor [arg...]
# Run scripts/doctor with the stub PATH and the fake HOME.
run_doctor() {
  run env PATH="${STUBS}" HOME="${FAKE_HOME}" \
    "${SCRIPTS_DIR}/doctor" "$@"
}

setup() {
  STUBS="${BATS_TEST_TMPDIR}/bin"
  FAKE_HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "${STUBS}" "${FAKE_HOME}"
  # The hermetic PATH below must still find the interpreter for the
  # #!/usr/bin/env shebangs, plus the neutral utilities that the
  # script boilerplate and lib.sh call. The tools under verdict stay
  # stubbed, so the machine that runs the suite cannot leak them.
  ln -s "$(command -v bash)" "${STUBS}/bash"
  ln -s "$(command -v dirname)" "${STUBS}/dirname"
  ln -s "$(command -v basename)" "${STUBS}/basename"
}

@test "doctor-cases.txt still defines every required case name" {
  require_case_names "${TESTDATA_DIR}/doctor-cases.txt" \
    args git-missing native-good go-missing go-old node-wrong pnpm-wrong \
    devshell-good devshell-no-direnv devshell-unwired
}

@test "args: an argument is a usage error" {
  run_doctor --wrong

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"usage: doctor"* ]]
}

@test "git-missing: no git on PATH fails the pre-flight" {
  make_stub "${STUBS}" go "go version go1.26.0 linux/amd64"
  make_stub "${STUBS}" node "v26.11.0"
  make_stub "${STUBS}" pnpm "11.24.0"

  run_doctor

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"git is not on PATH"* ]]
  [[ "${output}" == *"1 of 4 checks failed"* ]]
}

@test "native-good: git, go 1.26, node 26, and pnpm 11.24.0 pass" {
  make_stub "${STUBS}" git "git version 2.51.0"
  make_stub "${STUBS}" go "go version go1.26.0 linux/amd64"
  make_stub "${STUBS}" node "v26.11.0"
  make_stub "${STUBS}" pnpm "11.24.0"

  run_doctor

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"[✓] Git (2.51.0)"* ]]
  [[ "${output}" == *"[✓] Go (1.26.0)"* ]]
  [[ "${output}" == *"[✓] Node (v26.11.0)"* ]]
  [[ "${output}" == *"[✓] pnpm (11.24.0)"* ]]
  [[ "${output}" == *"all 4 checks passed"* ]]
}

@test "go-missing: no go on PATH prints the install fix" {
  make_stub "${STUBS}" git "git version 2.51.0"
  make_stub "${STUBS}" node "v26.11.0"
  make_stub "${STUBS}" pnpm "11.24.0"

  run_doctor

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"[✓] Git (2.51.0)"* ]]
  [[ "${output}" == *"[✗] go is not on PATH"* ]]
  [[ "${output}" == *"go is not on PATH"* ]]
  [[ "${output}" == *"see README section 'External contributors: install the tools on your OS'"* ]]
}

@test "go-old: go 1.24 fails the 1.25 floor with the upgrade fix" {
  make_stub "${STUBS}" git ""
  make_stub "${STUBS}" go "go version go1.24.1 linux/amd64"
  make_stub "${STUBS}" node "v26.11.0"
  make_stub "${STUBS}" pnpm "11.24.0"

  run_doctor

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"go 1.24.1 is too old"* ]]
  [[ "${output}" == *"the modules require at least go 1.25"* ]]
}

@test "node-wrong: node 24 fails the node 26 pin" {
  make_stub "${STUBS}" git ""
  make_stub "${STUBS}" go "go version go1.26.0 linux/amd64"
  make_stub "${STUBS}" node "v24.9.0"
  make_stub "${STUBS}" pnpm "11.24.0"

  run_doctor

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"node v24.9.0 is not node 26"* ]]
}

@test "pnpm-wrong: pnpm 11.23.0 fails the packageManager pin" {
  make_stub "${STUBS}" git ""
  make_stub "${STUBS}" go "go version go1.26.0 linux/amd64"
  make_stub "${STUBS}" node "v26.11.0"
  make_stub "${STUBS}" pnpm "11.23.0"

  run_doctor

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"pnpm 11.23.0 is not 11.24.0"* ]]
  [[ "${output}" == *"npm install -g pnpm@11.24.0"* ]]
}

@test "devshell-good: nix, direnv, and wired nix-direnv pass" {
  make_stub "${STUBS}" git "git version 2.51.0"
  make_stub "${STUBS}" nix "nix (Nix) 2.31.2"
  make_stub "${STUBS}" direnv "2.37.1"
  mkdir -p "${FAKE_HOME}/.config/direnv/lib"
  printf '# nix-direnv wiring\n' > "${FAKE_HOME}/.config/direnv/lib/nix-direnv.sh"

  run_doctor

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"[✓] Git (2.51.0)"* ]]
  [[ "${output}" == *"[✓] Nix (2.31.2)"* ]]
  [[ "${output}" == *"[✓] direnv (2.37.1)"* ]]
  [[ "${output}" == *"[✓] nix-direnv (wired)"* ]]
  [[ "${output}" == *"all 4 checks passed"* ]]
}

@test "devshell-no-direnv: nix without direnv prints the profile fix" {
  make_stub "${STUBS}" git "git version 2.51.0"
  make_stub "${STUBS}" nix "nix (Nix) 2.31.2"

  run_doctor

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"[✗] direnv is not on PATH"* ]]
  [[ "${output}" == *"direnv is not on PATH"* ]]
  [[ "${output}" == *"nix profile install nixpkgs#direnv"* ]]
}

@test "devshell-unwired: direnv without the nix-direnv wiring prints the symlink fix" {
  make_stub "${STUBS}" git "git version 2.51.0"
  make_stub "${STUBS}" nix "nix (Nix) 2.31.2"
  make_stub "${STUBS}" direnv "2.37.1"

  run_doctor

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"[✗] nix-direnv is not wired into direnv"* ]]
  [[ "${output}" == *"nix-direnv is not wired into direnv"* ]]
  [[ "${output}" == *"ln -s ~/.nix-profile/share/nix-direnv/direnvrc ~/.config/direnv/lib/nix-direnv.sh"* ]]
}
