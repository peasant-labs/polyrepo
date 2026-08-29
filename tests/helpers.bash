# helpers.bash - shared setup and assertion helpers for the polyrepo
# bats test suite. Load with `load 'helpers'` at the top of a .bats file.

# A fixed git identity, so fixture commits succeed offline with no user
# config. GIT_CONFIG_GLOBAL=/dev/null also stops the suite from reading
# a real global config on the machine that runs it.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME="polyrepo tests"
export GIT_AUTHOR_EMAIL="tests@polyrepo.invalid"
export GIT_COMMITTER_NAME="polyrepo tests"
export GIT_COMMITTER_EMAIL="tests@polyrepo.invalid"

POLYREPO_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export POLYREPO_TEST_ROOT
export SCRIPTS_DIR="${POLYREPO_TEST_ROOT}/scripts"
export TESTDATA_DIR="${POLYREPO_TEST_ROOT}/tests/testdata"

# setup_fixtures
# Build one bare fixture repository per line of
# tests/testdata/fixture-repos.txt, under $BATS_TEST_TMPDIR/remote/<name>.git.
# Each line reads: <name> <branches, comma separated, or -> <head branch, or ->.
# A branches value of - builds a bare repo with no branches at all.
# Also creates the workspace dir and exports POLYREPO_ROOT at it, so the
# scripts under test read repos.txt from there.
setup_fixtures() {
  local fixture_file="${TESTDATA_DIR}/fixture-repos.txt"
  local remote_dir="${BATS_TEST_TMPDIR}/remote"
  mkdir -p "${remote_dir}"

  export WS="${BATS_TEST_TMPDIR}/ws"
  mkdir -p "${WS}"
  export POLYREPO_ROOT="${WS}"

  local line name branches head
  while IFS= read -r line || [ -n "${line}" ]; do
    case "${line}" in
      ''|'#'*) continue ;;
    esac
    read -r name branches head <<< "${line}"
    local bare="${remote_dir}/${name}.git"

    if [ "${branches}" = "-" ]; then
      git init -q --bare "${bare}" > /dev/null
      continue
    fi

    local seed="${BATS_TEST_TMPDIR}/seed-${name}"
    git init -q "${seed}" > /dev/null
    (
      cd "${seed}" || exit 1
      local b
      local old_ifs="${IFS}"
      IFS=','
      for b in ${branches}; do
        IFS="${old_ifs}"
        git checkout -q -b "${b}"
        echo "${name} ${b}" > "file-${b}.txt"
        git add "file-${b}.txt"
        git commit -q -m "seed ${name} ${b}"
        IFS=','
      done
      IFS="${old_ifs}"
    )
    git clone -q --bare "${seed}" "${bare}" > /dev/null
    git -C "${bare}" symbolic-ref HEAD "refs/heads/${head}"
  done < "${fixture_file}"
}

# write_repos <line...>
# Write $WS/repos.txt with one line per argument.
write_repos() {
  printf '%s\n' "$@" > "${WS}/repos.txt"
}

# require_case_names <file> <name...>
# Assert that each given name is the first field of some non-blank,
# non-comment line in <file>. This is a deletion-protection check by
# NAME, not by count: removing a required case name from the file
# fails this check regardless of how many other lines remain.
require_case_names() {
  local file="$1"
  shift
  local name
  for name in "$@"; do
    if ! awk -v want="${name}" '
      /^[[:space:]]*#/ { next }
      /^[[:space:]]*$/ { next }
      { if ($1 == want) { found = 1 } }
      END { exit (found ? 0 : 1) }
    ' "${file}"; then
      echo "required case name '${name}' not found in ${file}" >&2
      return 1
    fi
  done
}

# push_commit <fixture-name> <branch>
# Add one new commit to <branch> of the named bare fixture repository,
# so tests can exercise a fast-forward pull.
push_commit() {
  local name="$1" branch="$2"
  local bare="${BATS_TEST_TMPDIR}/remote/${name}.git"
  local clone_dir
  clone_dir="${BATS_TEST_TMPDIR}/push-${name}-${branch}"
  git clone -q "${bare}" "${clone_dir}" > /dev/null
  (
    cd "${clone_dir}" || exit 1
    git checkout -q "${branch}"
    echo "update $(date +%s%N)" >> "file-${branch}.txt"
    git add "file-${branch}.txt"
    git commit -q -m "update ${name} ${branch}"
    git push -q origin "${branch}"
  )
}
