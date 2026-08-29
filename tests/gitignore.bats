#!/usr/bin/env bats
# Every repository dir named in repos.txt must be ignored by .gitignore,
# so a provisioned workspace never shows the clones as untracked files.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  # shellcheck source=scripts/lib.sh
  source "${REPO_ROOT}/scripts/lib.sh"
}

@test "every dir in repos.txt is ignored by .gitignore" {
  local found=0 _url dir
  while read -r _url dir; do
    found=1
    if ! git -C "${REPO_ROOT}" check-ignore -q "${dir}/"; then
      echo "not ignored: ${dir}"
      return 1
    fi
  done < <(read_repos "${REPO_ROOT}/repos.txt")
  [ "${found}" -eq 1 ]
}

@test "the repository's own directories are not ignored" {
  local d
  for d in scripts tests .github; do
    if git -C "${REPO_ROOT}" check-ignore -q "${d}/"; then
      echo "wrongly ignored: ${d}"
      return 1
    fi
  done
}
