#!/usr/bin/env bats
# sync-all.bats - tests for scripts/sync-all.

load 'helpers'

setup() {
  setup_fixtures
}

@test "sync-cases.txt still defines every required case name" {
  require_case_names "${TESTDATA_DIR}/sync-cases.txt" \
    ff uptodate hostmissing worktreemissing badline args
}

@test "ff: a fast-forward push is picked up by sync-all" {
  write_repos \
    "${BATS_TEST_TMPDIR}/remote/both.git both" \
    "${BATS_TEST_TMPDIR}/remote/mainonly.git mainonly"
  "${SCRIPTS_DIR}/provision-all" > /dev/null
  push_commit both develop

  run "${SCRIPTS_DIR}/sync-all"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"done: 2 synced, 0 failed"* ]]

  local want got
  want="$(git -C "${BATS_TEST_TMPDIR}/remote/both.git" rev-parse develop)"
  got="$(git -C "${WS}/both/develop" rev-parse HEAD)"
  [ "${want}" = "${got}" ]
}

@test "uptodate: a second run with nothing new reports the same summary" {
  write_repos \
    "${BATS_TEST_TMPDIR}/remote/both.git both" \
    "${BATS_TEST_TMPDIR}/remote/mainonly.git mainonly"
  "${SCRIPTS_DIR}/provision-all" > /dev/null
  push_commit both develop
  "${SCRIPTS_DIR}/sync-all" > /dev/null

  run "${SCRIPTS_DIR}/sync-all"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"done: 2 synced, 0 failed"* ]]
}

@test "hostmissing: a repository never provisioned fails with a fix pointing at provision-all" {
  write_repos "${BATS_TEST_TMPDIR}/remote/mainonly.git ghost"

  run "${SCRIPTS_DIR}/sync-all"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"1 failed"* ]]
  [[ "${output}" == *"run scripts/provision-all"* ]]
}

@test "worktreemissing: a pruned default-branch worktree fails with a worktree add fix" {
  write_repos "${BATS_TEST_TMPDIR}/remote/both.git both"
  "${SCRIPTS_DIR}/provision-all" > /dev/null
  rm -rf "${WS}/both/develop"
  git -C "${WS}/both" worktree prune

  run "${SCRIPTS_DIR}/sync-all"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"1 failed"* ]]
  [[ "${output}" == *"worktree add"* ]]
}

@test "badline: a malformed repos.txt line fails fast with no done line" {
  printf '%s\n' "onlyonefield" > "${WS}/repos.txt"

  run "${SCRIPTS_DIR}/sync-all"

  [ "${status}" -eq 2 ]
  [[ "${output}" != *"done:"* ]]
}

@test "args: any argument is a usage error" {
  run "${SCRIPTS_DIR}/sync-all" extra

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"usage:"* ]]
}
