#!/usr/bin/env bats
# git-provision.bats - tests for scripts/git-provision.

load 'helpers'

setup() {
  setup_fixtures
}

@test "provision-cases.txt still defines every required case name" {
  require_case_names "${TESTDATA_DIR}/provision-cases.txt" \
    both mainonly nobranch existing wrongargs
}

@test "git-provision handles each case in provision-cases.txt" {
  local case_file="${TESTDATA_DIR}/provision-cases.txt"
  local -a lines
  mapfile -t lines < "${case_file}"

  local line name fixture worktrees expect_exit
  for line in "${lines[@]}"; do
    case "${line}" in
      ''|'#'*) continue ;;
    esac
    read -r name fixture worktrees expect_exit <<< "${line}"
    local dir="${WS}/${name}"

    if [ "${name}" = "existing" ]; then
      mkdir -p "${dir}"
    fi

    if [ "${name}" = "wrongargs" ]; then
      run "${SCRIPTS_DIR}/git-provision" "one-arg-only"
      [ "${status}" -eq "${expect_exit}" ]
      [[ "${output}" == *"usage:"* ]]
      [ ! -e "${dir}" ]
      continue
    fi

    local url="${BATS_TEST_TMPDIR}/remote/${fixture}.git"
    run "${SCRIPTS_DIR}/git-provision" "${url}" "${dir}"
    [ "${status}" -eq "${expect_exit}" ]

    if [ "${expect_exit}" -ne 0 ]; then
      continue
    fi

    # Real git state, not just the exit code.
    local -a want_worktrees
    IFS=',' read -ra want_worktrees <<< "${worktrees}"
    local -a want_sorted
    mapfile -t want_sorted < <(printf '%s\n' "${want_worktrees[@]}" | sort)

    local -a all_paths actual
    mapfile -t all_paths < <(git -C "${dir}" worktree list --porcelain | awk '/^worktree /{print $2}')
    actual=()
    local p
    for p in "${all_paths[@]}"; do
      [ "${p}" = "${dir}" ] && continue
      actual+=("$(basename "${p}")")
    done
    local -a actual_sorted
    mapfile -t actual_sorted < <(printf '%s\n' "${actual[@]}" | sort)
    [ "${actual_sorted[*]}" = "${want_sorted[*]}" ]

    [ "$(git -C "${dir}" symbolic-ref --short HEAD)" = "__dummy__" ]
    [ -z "$(git -C "${dir}" status --porcelain)" ]

    local -a entries expected expected_sorted
    mapfile -t entries < <(ls -A "${dir}" | sort)
    expected=(.git .gitignore "${want_worktrees[@]}")
    mapfile -t expected_sorted < <(printf '%s\n' "${expected[@]}" | sort)
    [ "${entries[*]}" = "${expected_sorted[*]}" ]

    local b upstream
    for b in "${want_worktrees[@]}"; do
      upstream="$(git -C "${dir}/${b}" rev-parse --abbrev-ref '@{u}')"
      [ "${upstream}" = "origin/${b}" ]
    done
  done
}
