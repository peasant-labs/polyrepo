#!/usr/bin/env bash
# lib.sh - shared functions for the polyrepo provisioning scripts.
#
# The entry point scripts source this file. It defines message helpers,
# the repository list reader, and two git branch helpers.

# die <exit> <what> <why> <where> <fix>
# Print an actionable error to stderr and exit with the given code.
die() {
  local exit_code="$1" what="$2" why="$3" where="$4" fix="$5"
  local script_name
  script_name="$(basename "$0")"
  {
    echo "${script_name}: error: ${what}"
    echo "  why:   ${why}"
    echo "  where: ${where}"
    echo "  fix:   ${fix}"
  } >&2
  exit "${exit_code}"
}

# log <step> <detail>
# Print one progress line to stdout.
log() {
  local step="$1" detail="$2"
  local script_name
  script_name="$(basename "$0")"
  echo "${script_name}: ${step}: ${detail}"
}

# read_repos <file>
# Emit one validated "url dir" pair per line. Skip blank lines and lines
# that start with #. A line with a wrong field count, or a dir field that
# holds a slash or is . or .., is a data error (exit 2).
read_repos() {
  local file="$1"
  local line_no=0
  local url dir extra
  if [ ! -f "${file}" ]; then
    die 2 "repository list not found" \
      "the file ${file} does not exist" \
      "read_repos in scripts/lib.sh" \
      "create ${file}, or point POLYREPO_ROOT at the correct directory"
  fi
  while IFS= read -r line || [ -n "${line}" ]; do
    line_no=$((line_no + 1))
    case "${line}" in
      ''|'#'*) continue ;;
    esac
    url=""
    dir=""
    extra=""
    read -r url dir extra <<< "${line}"
    if [ -z "${url}" ] || [ -z "${dir}" ] || [ -n "${extra}" ]; then
      die 2 "bad repository list line" \
        "line ${line_no} of ${file} does not hold exactly two fields" \
        "read_repos in scripts/lib.sh, ${file}:${line_no}" \
        "edit ${file} so the line reads: <url> <dir>"
    fi
    case "${dir}" in
      */*|.|..)
        die 2 "bad repository directory name" \
          "the dir field '${dir}' on line ${line_no} of ${file} holds a slash, or is . or .." \
          "read_repos in scripts/lib.sh, ${file}:${line_no}" \
          "edit ${file} so the dir field is a single plain directory name"
        ;;
    esac
    echo "${url} ${dir}"
  done < "${file}"
}

# remote_branch_exists <dir> <branch>
# True when refs/remotes/origin/<branch> resolves in the repository at <dir>.
remote_branch_exists() {
  local dir="$1" branch="$2"
  git -C "${dir}" rev-parse --verify -q "refs/remotes/origin/${branch}" > /dev/null 2>&1
}

# default_branch <dir>
# Print the default branch name for the repository at <dir>, read from
# origin/HEAD. When origin/HEAD is unset, set it once, then read again.
default_branch() {
  local dir="$1"
  local ref
  ref="$(git -C "${dir}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -z "${ref}" ]; then
    git -C "${dir}" remote set-head origin --auto > /dev/null 2>&1 || true
    ref="$(git -C "${dir}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  fi
  echo "${ref#origin/}"
}
