#!/bin/bash
# Read-only check: local HEAD vs origin default (main vs master).

set -euo pipefail

print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Read-only report of the current branch versus origin's default
(origin/HEAD). Warns when local 'main' and 'master' both exist, or when
the current branch is main/master and origin's default is the other.

Must be run inside a Git work tree.

Options:
  -h, --help    Show this help and exit

Exit codes:
  0  Consistent (or origin/HEAD unset)
  1  Current branch is main/master and origin default is the other
  2  Usage error, git missing, or not a work tree
EOF
}

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

has_ref() {
  git show-ref --verify --quiet "$1"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        print_help
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        print_help >&2
        exit 2
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  if ! command -v git >/dev/null 2>&1; then
    err "git is not installed or not on PATH"
    exit 2
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "not inside a git work tree"
    exit 2
  fi

  local current origin_sym origin_default init_default
  current="$(git branch --show-current || true)"
  origin_default=""
  init_default="$(git config --get init.defaultBranch || true)"

  log "Git default-branch check (read-only)"
  if [[ -n "$current" ]]; then
    log "current branch: ${current}"
  else
    log "current branch: (detached HEAD)"
  fi
  if [[ -n "$init_default" ]]; then
    log "init.defaultBranch: ${init_default}"
  else
    log "init.defaultBranch: <unset>"
  fi

  if has_ref refs/heads/main; then
    log "local branch main: yes"
  else
    log "local branch main: no"
  fi
  if has_ref refs/heads/master; then
    log "local branch master: yes"
  else
    log "local branch master: no"
  fi

  if has_ref refs/heads/main && has_ref refs/heads/master; then
    log "note: both local main and master exist"
  fi

  if git symbolic-ref --quiet refs/remotes/origin/HEAD >/dev/null 2>&1; then
    origin_sym="$(git symbolic-ref --short refs/remotes/origin/HEAD)"
    origin_default="${origin_sym#origin/}"
    log "origin/HEAD: ${origin_sym}"
  else
    log "origin/HEAD: <unset>"
    log "hint: git remote set-head origin -a"
    log "OK: no origin default to compare"
    exit 0
  fi

  if [[ "$current" =~ ^(main|master)$ && "$origin_default" =~ ^(main|master)$ && "$current" != "$origin_default" ]]; then
    log "FAIL: current is ${current} but origin default is ${origin_default}"
    exit 1
  fi

  log "OK: current branch matches origin default (or is not main/master)"
  exit 0
}

main "$@"
