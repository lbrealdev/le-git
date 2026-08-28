#!/bin/bash
# Read-only audit of Git credential.helper (system / global / local / effective).

set -euo pipefail

print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Read-only report of credential.helper at each Git config scope,
including empty-reset semantics for the effective helper list.
Flags Git Credential Manager (GCM) values that often intercept HTTPS.

Options:
  -h, --help    Show this help and exit

Exit codes:
  0  No effective GCM manager helper
  1  Effective GCM manager helper is active
  2  Usage error or git missing
EOF
}

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

is_gcm_helper() {
  local val="$1"
  case "$val" in
    manager|manager-core|manager-core.exe|\
    git-credential-manager|git-credential-manager.exe|\
    git-credential-manager-core|git-credential-manager-core.exe)
      return 0
      ;;
    *git-credential-manager*)
      return 0
      ;;
  esac
  return 1
}

effective_helpers() {
  local helper
  local -a helpers=()
  while IFS= read -r helper; do
    if [[ "$helper" == "" ]]; then
      helpers=()
      continue
    fi
    helpers+=("$helper")
  done < <(git config --get-all credential.helper 2>/dev/null || true)

  if ((${#helpers[@]} > 0)); then
    printf '%s\n' "${helpers[@]}"
  fi
}

print_scope_helpers() {
  local scope="$1"
  log ""
  log "== ${scope} credential.* =="
  if git config --"${scope}" --get-regexp '^credential\.' >/dev/null 2>&1; then
    git config --"${scope}" --get-regexp '^credential\.'
  else
    log "(none or unreadable)"
  fi
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

  log "Git credential.helper audit (read-only)"
  log "git: $(git --version)"
  if [[ -n "${GIT_CONFIG_NOSYSTEM:-}" ]]; then
    log "GIT_CONFIG_NOSYSTEM is set (system gitconfig ignored)"
  else
    log "GIT_CONFIG_NOSYSTEM=<unset>"
  fi

  print_scope_helpers system
  print_scope_helpers global
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_scope_helpers local
  else
    log ""
    log "== local credential.* =="
    log "(not inside a git work tree; skipped)"
  fi

  log ""
  log "== origins (raw credential.helper) =="
  if git config --list --show-origin 2>/dev/null | grep -F 'credential.helper'; then
    :
  else
    log "(none)"
  fi

  log ""
  log "== effective credential.helper (after empty-reset) =="
  local -a effective=()
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    effective+=("$line")
  done < <(effective_helpers)

  local gcm=0
  if ((${#effective[@]} == 0)); then
    log "(none)"
  else
    for line in "${effective[@]}"; do
      printf '%s\n' "$line"
      if is_gcm_helper "$line"; then
        gcm=1
      fi
    done
  fi

  log ""
  if [[ "$gcm" -eq 1 ]]; then
    log "FAIL: GCM manager helper is effective"
    exit 1
  fi
  log "OK: no effective GCM manager helper"
  exit 0
}

main "$@"
