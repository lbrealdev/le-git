#!/bin/bash
# Write: copy a GitHub repo's default branch into a new repo as one fresh
# commit. Destination auth via TARGET_TOKEN (preferred) or gh fallback.
# Optional SOURCE_TOKEN for private source clones.

set -euo pipefail

TMPDIR_PATH=""
AUTH_MODE=""

print_help() {
  cat << EOF
Usage: $(basename "$0") <source-owner/repo> <dest-owner/repo> [--public]

Migrate a PUBLIC GitHub repository's default branch into a NEW repository
with identical tree content but a single fresh commit on main (no history,
no issues/PRs). Destination is private unless --public is passed.

Arguments:
  source-owner/repo   Public repository to copy from (anonymous HTTPS)
  dest-owner/repo     New repository to create (must not exist)

Options:
  --public      Create the destination as a public repository
  -h, --help    Show this help and exit

Auth (destination only):
  Preferred: export TARGET_TOKEN to a GitHub token that can create the dest.
  Fallback:  if TARGET_TOKEN is unset, use an authenticated gh CLI.

Exit codes:
  0  Migration succeeded
  1  Runtime failure (clone, create, push, or destination exists)
  2  Usage error, missing tools, or no destination credentials
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
  printf '%-14s %s\n' "$1" "$2"
}

# Never prompt: no terminal, askpass GUI, credential manager, or gh dialog.
export GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GCM_GUI_PROMPT=false
export GIT_ASKPASS=/bin/false SSH_ASKPASS=/bin/false GH_PROMPT_DISABLED=1

# Non-interactive HTTPS git. The empty credential.helper resets inherited
# helpers (e.g. manager); when GIT_AUTH_TOKEN is set, an inline helper reads
# it from the env at call time (never in argv, URL, config, or output).
# shellcheck disable=SC2016
git_https() {
  local helper=()
  if [[ -n "${GIT_AUTH_TOKEN:-}" ]]; then
    helper=(-c 'credential.helper=!f(){ echo username=x-access-token; echo "password=${GIT_AUTH_TOKEN}"; }; f')
  fi
  git -c credential.helper= "${helper[@]}" \
    -c credential.interactive=false -c core.askPass=/bin/false "$@"
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

  DEST_OWNER="${DEST_REPO%%/*}"
  DEST_NAME="${DEST_REPO#*/}"
}

require_tools_and_auth() {
  if ! command -v git > /dev/null 2>&1; then
    err "git is not installed or not on PATH"
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

  if [[ -n "${TARGET_TOKEN:-}" ]]; then
    AUTH_MODE="token"
    if ! command -v curl > /dev/null 2>&1; then
      err "curl is not installed or not on PATH (required with TARGET_TOKEN)"
      exit 2
    fi
    if ! command -v jq > /dev/null 2>&1; then
      err "jq is not installed or not on PATH (required with TARGET_TOKEN)"
      exit 2
    fi
    return 0
  fi

  if command -v gh > /dev/null 2>&1 && gh auth status > /dev/null 2>&1; then
    AUTH_MODE="gh"
    return 0
  fi

  err "No destination credentials."
  err "Export TARGET_TOKEN to a GitHub token that can create ${DEST_REPO},"
  err "or install/authenticate gh (gh auth login / gh auth switch)."
  exit 2
}

api_json() {
  # Usage: api_json METHOD URL [curl -d payload...]
  # Prints response body on stdout. Uses TARGET_TOKEN; never prints it.
  local method="$1"
  local url="$2"
  shift 2
  curl -sS \
    -X "$method" \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${TARGET_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$@" \
    "$url"
}

token_user_login() {
  local body
  body="$(api_json GET "https://api.github.com/user")"
  jq -er '.login' <<< "$body"
}

dest_exists_token() {
  local code
  code="$(
    curl -sS -o /dev/null -w '%{http_code}' \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${TARGET_TOKEN}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/${DEST_REPO}"
  )"
  case "$code" in
    200) return 0 ;;
    404) return 1 ;;
    *)
      err "failed to check destination (${DEST_REPO}): HTTP ${code}"
      exit 1
      ;;
  esac
}

dest_exists_gh() {
  gh repo view "$DEST_REPO" > /dev/null 2>&1
}

ensure_dest_absent() {
  local exists=1
  if [[ "$AUTH_MODE" == "token" ]]; then
    if dest_exists_token; then
      exists=0
    fi
  else
    if dest_exists_gh; then
      exists=0
    fi
  fi

  if [[ "$exists" -eq 0 ]]; then
    err "destination already exists: ${DEST_REPO}"
    err "Refusing to overwrite or force-push. Choose a new name."
    exit 1
  fi
}

create_dest_token() {
  local token_user private_json endpoint payload body message
  token_user="$(token_user_login)"
  if [[ "$VISIBILITY" == "public" ]]; then
    private_json="false"
  else
    private_json="true"
  fi

  payload="$(
    jq -nc --arg name "$DEST_NAME" --argjson private "$private_json" \
      '{name: $name, private: $private, auto_init: false}'
  )"

  if [[ "$DEST_OWNER" == "$token_user" ]]; then
    endpoint="https://api.github.com/user/repos"
  else
    endpoint="https://api.github.com/orgs/${DEST_OWNER}/repos"
  fi

  body="$(api_json POST "$endpoint" -H "Content-Type: application/json" -d "$payload")" || {
    err "failed to create destination: ${DEST_REPO}"
    exit 1
  }

  if ! jq -e '.id' <<< "$body" > /dev/null 2>&1; then
    message="$(jq -r '.message // "unknown error"' <<< "$body" 2> /dev/null || true)"
    err "failed to create destination: ${DEST_REPO}"
    if [[ -n "$message" && "$message" != "null" ]]; then
      err "${message}"
    fi
    err "Destination must not already exist (no overwrite / force-push)."
    exit 1
  fi
}

is_workflow_scope_rejection() {
  local log_file="$1"
  grep -Eiq \
    'workflow.*scope|without `workflow`|refusing to allow.*(workflow|Personal Access Token to create or update workflow)' \
    "$log_file"
}

print_workflow_scope_fix() {
  err "Push rejected: token cannot write files under .github/workflows/."
  err "Fix TARGET_TOKEN scopes, then retry (destination may already exist):"
  err "  classic PAT:    repo + workflow"
  err "  fine-grained:   Contents (read/write), Workflows (read/write),"
  err "                  plus Administration (for repository creation)"
}

clone_source() {
  local clone_err
  clone_err="${TMPDIR_PATH}/clone.err"

  if [[ -n "${SOURCE_TOKEN:-}" ]]; then
    log "Cloning source (depth 1, SOURCE_TOKEN)..."
    if ! GIT_AUTH_TOKEN="$SOURCE_TOKEN" git_https clone --depth 1 \
      "https://github.com/${SOURCE_REPO}.git" "${TMPDIR_PATH}/src" \
      > /dev/null 2> "$clone_err"; then
      cat "$clone_err" >&2 || true
      err "failed to clone source: ${SOURCE_REPO}"
      err "Check SOURCE_TOKEN access to the source repository."
      exit 1
    fi
    return 0
  fi

  log "Cloning source (depth 1, anonymous HTTPS)..."
  if ! git_https clone --depth 1 "https://github.com/${SOURCE_REPO}.git" \
    "${TMPDIR_PATH}/src" > /dev/null 2> "$clone_err"; then
    cat "$clone_err" >&2 || true
    err "failed to clone source: ${SOURCE_REPO}"
    if grep -Eiq \
      'not found|Authentication failed|could not read Username|Invalid username or password|fatal: repository' \
      "$clone_err"; then
      err "If the source is private, export SOURCE_TOKEN and retry."
    else
      err "Source must be reachable anonymously, or set SOURCE_TOKEN."
    fi
    exit 1
  fi
}

push_dest_token() {
  # Token via env-backed inline helper. Never written to config/remote/output.
  local push_err
  push_err="${TMPDIR_PATH}/push.err"

  git remote remove origin > /dev/null 2>&1 || true
  git remote add origin "https://github.com/${DEST_REPO}.git"

  if ! GIT_AUTH_TOKEN="$TARGET_TOKEN" git_https \
    push -u origin main > /dev/null 2> "$push_err"; then
    cat "$push_err" >&2 || true
    err "failed to push main to ${DEST_REPO}"
    if is_workflow_scope_rejection "$push_err"; then
      print_workflow_scope_fix
    else
      err "Check TARGET_TOKEN scopes and that the destination exists."
    fi
    err "Refusing to force-push."
    exit 1
  fi
}

create_and_push_gh() {
  local visibility_flag push_err
  if [[ "$VISIBILITY" == "public" ]]; then
    visibility_flag="--public"
  else
    visibility_flag="--private"
  fi

  push_err="${TMPDIR_PATH}/push.err"
  # Create with gh, then push through git_https with gh's token.
  if ! gh repo create "$DEST_REPO" "$visibility_flag" > /dev/null 2> "$push_err" ||
    ! git remote add origin "https://github.com/${DEST_REPO}.git" 2>> "$push_err" ||
    ! GIT_AUTH_TOKEN="$(gh auth token)" git_https push -u origin main \
      > /dev/null 2>> "$push_err"; then
    cat "$push_err" >&2 || true
    err "failed to create or push destination: ${DEST_REPO}"
    if is_workflow_scope_rejection "$push_err"; then
      print_workflow_scope_fix
    else
      err "If auth is wrong, run: gh auth login / gh auth switch"
      err "Or export TARGET_TOKEN instead."
    fi
    err "Destination must not already exist (no overwrite / force-push)."
    exit 1
  fi
}

count_files() {
  find . -type f ! -path './.git/*' | wc -l | tr -d '[:space:]'
}

main() {
  parse_args "$@"
  require_tools_and_auth

  trap cleanup EXIT

  log "migrate-repo-fresh"
  log "------------------"
  row "source:" "$SOURCE_REPO"
  row "destination:" "$DEST_REPO"
  row "visibility:" "$VISIBILITY"
  row "auth:" "$AUTH_MODE"
  if [[ -n "${SOURCE_TOKEN:-}" ]]; then
    row "source-auth:" "SOURCE_TOKEN"
  else
    row "source-auth:" "anonymous"
  fi
  log ""

  ensure_dest_absent

  TMPDIR_PATH="$(mktemp -d "${TMPDIR:-/tmp}/migrate-repo-fresh.XXXXXX")"
  row "workdir:" "$TMPDIR_PATH"

  log ""
  clone_source

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

  log ""
  log "Creating destination and pushing main..."
  if [[ "$AUTH_MODE" == "token" ]]; then
    create_dest_token
    push_dest_token
  else
    create_and_push_gh
  fi

  local dest_url="https://github.com/${DEST_REPO}"

  log ""
  row "url:" "$dest_url"
  log "verdict: migrated ${SOURCE_REPO} -> ${DEST_REPO} (${file_count} files) ${dest_url}"
}

main "$@"
