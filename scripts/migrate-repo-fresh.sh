#!/bin/bash
# Write: copy a GitHub repo's default branch into a new repo as one fresh commit.

set -euo pipefail

TMPDIR_PATH=""

print_help() {
  cat << EOF
Usage: $(basename "$0") <source-owner/repo> <dest-owner/repo> [--public]

Migrate a GitHub repository's default branch into a NEW repository with
identical tree content but a single fresh commit on main (no history,
no issues/PRs). Destination is private unless --public is passed.

Arguments:
  source-owner/repo   Existing repository to copy from
  dest-owner/repo     New repository to create (must not exist)

Options:
  --public      Create the destination as a public repository
  -h, --help    Show this help and exit

Exit codes:
  0  Migration succeeded
  1  Runtime failure (clone, create, push, or destination exists)
  2  Usage error, or git/gh missing or unauthenticated
EOF
}

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

cleanup() {
  if [[ -n "${TMPDIR_PATH}" && -d "${TMPDIR_PATH}" ]]; then
    rm -rf "${TMPDIR_PATH}"
  fi
}

row() {
  # Aligned key/value line: fixed 14-char label column.
  printf '%-14s %s\n' "$1" "$2"
}

require_owner_repo() {
  local value="$1"
  local label="$2"
  if [[ ! "$value" =~ ^[^/]+/[^/]+$ ]]; then
    err "${label} must be owner/repo (got: ${value})"
    print_help >&2
    exit 2
  fi
}

parse_args() {
  SOURCE_REPO=""
  DEST_REPO=""
  VISIBILITY="private"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        print_help
        exit 0
        ;;
      --public)
        VISIBILITY="public"
        shift
        ;;
      -*)
        err "Unknown option: $1"
        print_help >&2
        exit 2
        ;;
      *)
        if [[ -z "$SOURCE_REPO" ]]; then
          SOURCE_REPO="$1"
        elif [[ -z "$DEST_REPO" ]]; then
          DEST_REPO="$1"
        else
          err "Unexpected argument: $1"
          print_help >&2
          exit 2
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$SOURCE_REPO" || -z "$DEST_REPO" ]]; then
    err "source and destination owner/repo are required"
    print_help >&2
    exit 2
  fi

  require_owner_repo "$SOURCE_REPO" "source"
  require_owner_repo "$DEST_REPO" "destination"

  if [[ "$SOURCE_REPO" == "$DEST_REPO" ]]; then
    err "source and destination must differ"
    exit 2
  fi
}

require_tools() {
  if ! command -v git > /dev/null 2>&1; then
    err "git is not installed or not on PATH"
    exit 2
  fi
  if ! command -v gh > /dev/null 2>&1; then
    err "gh is not installed or not on PATH"
    err "Install GitHub CLI, then run: gh auth login"
    exit 2
  fi
  if ! gh auth status > /dev/null 2>&1; then
    err "gh is not authenticated for the destination account"
    err "Run: gh auth login"
    err "Or switch account: gh auth switch"
    exit 2
  fi

  local git_user git_email
  git_user="$(git config --get user.name || true)"
  git_email="$(git config --get user.email || true)"
  if [[ -z "$git_user" || -z "$git_email" ]]; then
    err "git user.name / user.email are not set"
    err "Configure your identity, then retry."
    exit 2
  fi
}

dest_exists() {
  gh repo view "$DEST_REPO" > /dev/null 2>&1
}

count_files() {
  find . -type f ! -path './.git/*' | wc -l | tr -d '[:space:]'
}

main() {
  parse_args "$@"
  require_tools

  trap cleanup EXIT

  log "migrate-repo-fresh"
  log "------------------"
  row "source:" "$SOURCE_REPO"
  row "destination:" "$DEST_REPO"
  row "visibility:" "$VISIBILITY"
  log ""

  if dest_exists; then
    err "destination already exists: ${DEST_REPO}"
    err "Refusing to overwrite or force-push. Choose a new name."
    exit 1
  fi

  TMPDIR_PATH="$(mktemp -d "${TMPDIR:-/tmp}/migrate-repo-fresh.XXXXXX")"
  row "workdir:" "$TMPDIR_PATH"

  log ""
  log "Cloning source (depth 1, default branch)..."
  if ! git clone --depth 1 "https://github.com/${SOURCE_REPO}.git" \
    "${TMPDIR_PATH}/src"; then
    err "failed to clone source: ${SOURCE_REPO}"
    err "Check that the repository exists and you have access."
    exit 1
  fi

  cd "${TMPDIR_PATH}/src"
  rm -rf .git

  git init -b main
  git add -A

  local file_count
  file_count="$(count_files)"
  row "files:" "$file_count"

  if ! git commit --allow-empty -m "Initial commit" > /dev/null; then
    err "failed to create Initial commit"
    exit 1
  fi

  local visibility_flag
  if [[ "$VISIBILITY" == "public" ]]; then
    visibility_flag="--public"
  else
    visibility_flag="--private"
  fi

  log ""
  log "Creating destination and pushing main..."
  if ! gh repo create "$DEST_REPO" "$visibility_flag" --source . --push; then
    err "failed to create or push destination: ${DEST_REPO}"
    err "If auth is wrong for that account, run: gh auth login"
    err "Or switch account: gh auth switch"
    err "Destination must not already exist (no overwrite / force-push)."
    exit 1
  fi

  local dest_url
  dest_url="$(gh repo view "$DEST_REPO" --json url -q .url 2> /dev/null || true)"
  if [[ -z "$dest_url" ]]; then
    dest_url="https://github.com/${DEST_REPO}"
  fi

  log ""
  row "url:" "$dest_url"
  log "verdict: migrated ${SOURCE_REPO} -> ${DEST_REPO} (${file_count} files) ${dest_url}"
}

main "$@"
