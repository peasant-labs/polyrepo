#!/usr/bin/env bats
# provision-all.bats - tests for scripts/provision-all.

load 'helpers'

setup() {
  setup_fixtures
}

@test "provision-all-cases.txt still defines every required case name" {
  require_case_names "${TESTDATA_DIR}/provision-all-cases.txt" \
    fresh rerun mixed badline badurl args
}

@test "fresh: provisions every repository that is not yet present" {
  write_repos \
    "${BATS_TEST_TMPDIR}/remote/both.git both" \
    "${BATS_TEST_TMPDIR}/remote/mainonly.git mainonly"

  run "${SCRIPTS_DIR}/provision-all"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"done: 2 provisioned, 0 skipped, 0 failed"* ]]
}

@test "rerun: a second run skips repositories already provisioned" {
  write_repos \
    "${BATS_TEST_TMPDIR}/remote/both.git both" \
    "${BATS_TEST_TMPDIR}/remote/mainonly.git mainonly"
  "${SCRIPTS_DIR}/provision-all" > /dev/null

  run "${SCRIPTS_DIR}/provision-all"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"done: 0 provisioned, 2 skipped, 0 failed"* ]]
}

@test "mixed: a pre-created directory is skipped, the other repo is provisioned" {
  write_repos \
    "${BATS_TEST_TMPDIR}/remote/both.git both" \
    "${BATS_TEST_TMPDIR}/remote/mainonly.git mainonly"
  mkdir -p "${WS}/both"

  run "${SCRIPTS_DIR}/provision-all"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1 provisioned, 1 skipped, 0 failed"* ]]
}

@test "badline: a malformed repos.txt line fails fast with no done line" {
  printf '%s\n' "onlyonefield" > "${WS}/repos.txt"

  run "${SCRIPTS_DIR}/provision-all"

  [ "${status}" -eq 2 ]
  [[ "${output}" != *"done:"* ]]
}

@test "badurl: one bad repository fails, the good one still provisions" {
  write_repos \
    "${WS}/does-not-exist badurl" \
    "${BATS_TEST_TMPDIR}/remote/mainonly.git mainonly"

  run "${SCRIPTS_DIR}/provision-all"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"1 provisioned, 0 skipped, 1 failed"* ]]
}

@test "args: any argument is a usage error" {
  run "${SCRIPTS_DIR}/provision-all" extra

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"usage:"* ]]
}
