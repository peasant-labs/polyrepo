#!/usr/bin/env bats
# install-toolchain.bats - safety-boundary tests for the native installer.

load 'helpers'

make_stub() {
  local name="$1" body="$2"
  {
    echo '#!/usr/bin/env bash'
    printf '%s\n' "$body"
  } > "${STUBS}/${name}"
  chmod +x "${STUBS}/${name}"
}

setup() {
  STUBS="${BATS_TEST_TMPDIR}/bin"
  FAKE_HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$STUBS" "$FAKE_HOME"
  ln -s "$(command -v bash)" "${STUBS}/bash"
  ln -s "$(command -v basename)" "${STUBS}/basename"
}

run_installer() {
  run env PATH="$STUBS" HOME="$FAKE_HOME" \
    "${SCRIPTS_DIR}/install-toolchain" "$@"
}

@test "install-toolchain-cases.txt still defines every required case name" {
  require_case_names "${TESTDATA_DIR}/install-toolchain-cases.txt" \
    args unsupported-os noninteractive-refusal user-local-go \
    pnpm-unavailable pnpm-older pnpm-supported
  require_case_names "${TESTDATA_DIR}/install-toolchain-pnpm-cases.txt" \
    missing failing invalid pnpm-9 pnpm-10 pnpm-11 pnpm-20
}

@test "args: an argument fails before any dependency check" {
  run_installer --wrong

  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: install-toolchain"* ]]
}

@test "unsupported-os: an unknown OS fails before any install" {
  make_stub curl "printf '%s\n' 'unused'"
  make_stub tar "exit 0"
  make_stub uname "printf '%s\n' Plan9"
  make_stub sed "exit 0"
  make_stub awk "exit 0"

  run_installer

  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported operating system: Plan9"* ]]
  [ ! -e "$FAKE_HOME/go" ]
}

@test "noninteractive-refusal: no terminal makes no change" {
  make_stub curl "printf '%s\n' '[{\"version\": \"go1.26.3\",\"files\":[' '{\"filename\": \"go1.26.3.linux-amd64.tar.gz\",' '\"sha256\": \"abc123\"}]}]'"
  make_stub tar "exit 0"
  make_stub uname 'if [ "$1" = "-s" ]; then printf "%s\n" Linux; else printf "%s\n" x86_64; fi'
  ln -s "$(command -v sed)" "${STUBS}/sed"
  ln -s "$(command -v awk)" "${STUBS}/awk"

  run_installer

  [ "$status" -eq 1 ]
  [[ "$output" == *"no terminal is available for confirmation"* ]]
  [[ "$output" == *"Go             1.26.3 -> $FAKE_HOME/.local/share/go/1.26.3"* ]]
  [ ! -e "$FAKE_HOME/go" ]
  [ ! -e "$FAKE_HOME/.local/share/go" ]
}

prepare_successful_install() {
  for command in chmod mkdir mktemp mv rm; do
    ln -s "$(command -v "$command")" "${STUBS}/${command}"
  done
  make_stub uname 'if [ "$1" = "-s" ]; then printf "%s\n" Linux; else printf "%s\n" x86_64; fi'
  ln -s "$(command -v sed)" "${STUBS}/sed"
  ln -s "$(command -v awk)" "${STUBS}/awk"
  make_stub sha256sum "printf '%s  %s\n' abc123 \"\$1\""
  make_stub tar '
dest=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-C" ]; then shift; dest="$1"; fi
  shift
done
mkdir -p "$dest/go/bin"
printf "#!/usr/bin/env bash\n" > "$dest/go/bin/go"
chmod +x "$dest/go/bin/go"'
  make_stub curl '
case "$*" in
  *mode=json*)
    printf "%s\n" "[{\"version\": \"go1.26.3\",\"files\":[" "{\"filename\": \"go1.26.3.linux-amd64.tar.gz\"," "\"sha256\": \"abc123\"}]}]"
    ;;
  *fnm.vercel.app*)
    output="${@: -1}"
    : > "$output"
    mkdir -p "$HOME/.local/share/fnm"
    printf "#!/usr/bin/env bash\nprintf \":\\n\"\n" > "$HOME/.local/share/fnm/fnm"
    chmod +x "$HOME/.local/share/fnm/fnm"
    ;;
  *)
    output="${@: -1}"
    : > "$output"
    ;;
esac'
  make_stub npm '
  printf "%s\n" "$@" > "$HOME/npm-args"
  [ "$#" -eq 3 ] &&
  [ "$1" = "install" ] &&
  [ "$2" = "--global" ] &&
  [ "$3" = "pnpm@11.24.0" ]
  '
}

run_successful_install() {
  run env PATH="$STUBS" HOME="$FAKE_HOME" POLYREPO_YES=1 \
    POLYREPO_GO_VERSION=1.26.3 "${SCRIPTS_DIR}/install-toolchain"
}

@test "user-local-go: installs the SDK outside the default GOPATH" {
  prepare_successful_install
  run_successful_install

  [ "$status" -eq 0 ]
  [ -x "$FAKE_HOME/.local/share/go/1.26.3/bin/go" ]
  [ ! -e "$FAKE_HOME/go/1.26.3" ]
  [[ "$output" == *"via npm"* ]]
  [[ "$output" == *'export PATH="$HOME/.local/share/go/1.26.3/bin:$HOME/.local/share/fnm:$HOME/go/bin:$PATH"'* ]]
}

run_pnpm_cases() {
  local group="$1" case_group name version exit_code expected
  while read -r name case_group version exit_code expected; do
    [ "$case_group" = "$group" ] || continue
    echo "checking $name" >&3
    STUBS="${BATS_TEST_TMPDIR}/${name}/bin"
    FAKE_HOME="${BATS_TEST_TMPDIR}/${name}/home"
    mkdir -p "$STUBS" "$FAKE_HOME"
    ln -s "$(command -v bash)" "${STUBS}/bash"
    prepare_successful_install
    if [ "$version" != "missing" ]; then
      make_stub pnpm "printf '%s\n' '$version'; exit $exit_code"
    fi

    run_successful_install

    [ "$status" -eq 0 ] || return 1
    if [ "$expected" = "install" ]; then
      [ -f "$FAKE_HOME/npm-args" ] || return 1
      [ "$(cat "$FAKE_HOME/npm-args")" = "$(printf '%s\n' install --global pnpm@11.24.0)" ] || return 1
      [[ "$output" == *"via npm"* ]] || return 1
    else
      [ ! -e "$FAKE_HOME/npm-args" ] || return 1
      [[ "$output" == *"pnpm ${version} is already installed; keeping it."* ]] || return 1
    fi
  done < "${TESTDATA_DIR}/install-toolchain-pnpm-cases.txt"
}

@test "pnpm-unavailable: installs when pnpm is missing, failing, or invalid" {
  run_pnpm_cases unavailable
}

@test "pnpm-older: installs when pnpm is older than 10" {
  run_pnpm_cases older
}

@test "pnpm-supported: preserves installed pnpm 10 or newer" {
  run_pnpm_cases supported
}
