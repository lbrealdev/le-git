#!/usr/bin/env bash
# Write: move a GitHub repository (transfer, mirror, or single commit).

set -euo pipefail

MODE=transfer
DRY_RUN=0
YES=0
QUIET=0
TARGET_VISIBILITY=''
NO_TAGS=0
SOURCE=''
TARGET_OWNER=''
TARGET_NAME=''
TARGET_USER=''
SOURCE_USER=''
SOURCE_AUTH=''
TARGET_AUTH=''
SOURCE_VISIBILITY=''
SOURCE_DEFAULT_BRANCH=''
TARGET_EXISTS=0
TMPDIR_PATH=''
HOST_IDENTITY=0
BRANCHES=()
HAVE_JQ=0
HAVE_GH=0

out() { [[ "$QUIET" -eq 1 ]] || printf '%s\n' "$*"; }
# One blank line before every error: (separates status / prompt); never doubles.
err() { printf '\nerror: %s\n' "$*" >&2; }
die() { err "$1"; exit 1; }
usage_die() { err "$1 Try --help."; exit 2; }
# Closing success / dry-run line: one blank before it (respect -q).
closing() { [[ "$QUIET" -eq 1 ]] || printf '\n%s\n' "$*"; }
ok() { out "  ok  $1"; }
warn() { out "  !!  $*"; }
info() { out "  i   $*"; }
target_slug() { printf '%s/%s' "$TARGET_OWNER" "$TARGET_NAME"; }

# Fold captured child stderr into one error: line.
# Visible line: one sentence (+ optional reason/action). No colon after "error:".
die_from_cmd() {
  local lead="$1" errf="$2" hint="${3:-}" raw msg
  raw="$(cat "$errf" 2>/dev/null || true)"
  rm -f "$errf"
  msg="$(printf '%s\n' "$raw" | sed -n -e 's/^gh: //p' -e 's/^fatal: //p' -e 's/^curl: //p' | head -n 1)"
  if [[ -z "$msg" ]]; then
    msg="$(printf '%s\n' "$raw" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  fi
  if [[ -z "$msg" ]]; then
    msg="$(printf '%s\n' "$raw" | sed -n -E 's/^HTTP [0-9]+[[:space:]]*:[[:space:]]*//p' | head -n 1)"
  fi
  if [[ -z "$msg" ]]; then
    msg="$(printf '%s\n' "$raw" | sed '/^$/d' | head -n 1)"
  fi
  # Plain words only: drop HTTP prefixes and colons so we never emit "error: a: b".
  msg="$(printf '%s\n' "$msg" | sed -E 's/^HTTP [0-9]+[[:space:]]*:[[:space:]]*//; s/\. \((HTTP\)/ \1/; s/: / /g')"
  msg="${msg%.}"
  if [[ -n "$msg" && -n "$hint" ]]; then
    die "${lead}. ${msg}. ${hint}"
  elif [[ -n "$msg" ]]; then
    die "${lead}. ${msg}."
  elif [[ -n "$hint" ]]; then
    die "${lead}. ${hint}"
  else
    die "${lead}."
  fi
}

# 404/401/403 on a repo read: not found or no access (ambiguous).
die_repo_inaccessible() {
  die "$1 was not found, or your credentials cannot access it."
}

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate.sh <owner/repo> [<target-owner>[/<name>]] [options]

Move a GitHub repository to another owner (transfer, mirror, or single commit).
Auth: SOURCE_TOKEN/TARGET_TOKEN, else GH_TOKEN, else GITHUB_TOKEN, else gh.

Modes:
  (default)           Native transfer (requires admin on the source)
  --mirror            Clone --mirror and push to a new target repo
  --single-commit     Copy the default branch as one fresh commit

Options:
  --branch <name>     With --mirror: push only these branches (repeatable)
  --no-tags           With --mirror: do not push tags
  --public            Target visibility (mirror / single-commit)
  --private           Target visibility (mirror / single-commit)
  --host-identity     With --single-commit: use this host's git identity
  -n, --dry-run       Show plan; change nothing
  -y, --yes           Skip confirmation prompt
  -q, --quiet         Hide non-error stdout
  -h, --help          Show this help and exit

Examples:
  ./scripts/gh-repo-migrate.sh acme/widget new-co
  ./scripts/gh-repo-migrate.sh acme/widget new-co --mirror --branch main
  ./scripts/gh-repo-migrate.sh acme/widget --single-commit -n
EOF
}

# Resolve once: side-specific token, then GH_TOKEN, GITHUB_TOKEN, then gh auth token.
resolve_side_token() {
  local side="$1" specific="${2:-}"
  if [[ -n "$specific" ]]; then
    printf '%s' "$specific"
    return 0
  fi
  if [[ -n "${GH_TOKEN:-}" ]]; then
    printf '%s' "$GH_TOKEN"
    return 0
  fi
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    printf '%s' "$GITHUB_TOKEN"
    return 0
  fi
  if [[ "$HAVE_GH" -eq 1 ]]; then
    local tok
    if tok="$(gh auth token 2>/dev/null)" && [[ -n "$tok" ]]; then
      printf '%s' "$tok"
      return 0
    fi
  fi
  err "no credentials for ${side}. Set ${side}_TOKEN or log in with gh."
  return 1
}

# GitHub REST via curl. Auth header via --config on stdin (never argv or disk).
# Usage: api_request TOKEN METHOD PATH [json_body]  -> body on stdout, 0 on 2xx.
# On failure: HTTP status + body on stderr (caller redirects to errf).
api_request() {
  local token="$1" method="$2" path="$3" body="${4:-}"
  local out code bodyfile='' rc=0 msg
  out="$(mktemp)"
  if [[ -n "$body" ]]; then
    bodyfile="$(mktemp)"
    printf '%s' "$body" >"$bodyfile"
  fi
  # printf is a builtin; config (with Authorization) never lands in a temp file.
  code="$(
    {
      printf 'url = "https://api.github.com/%s"\n' "$path"
      printf 'request = "%s"\n' "$method"
      printf 'header = "Authorization: Bearer %s"\n' "$token"
      printf 'header = "Accept: application/vnd.github+json"\n'
      printf 'header = "X-GitHub-Api-Version: 2022-11-28"\n'
      if [[ -n "$bodyfile" ]]; then
        printf 'header = "Content-Type: application/json"\n'
        printf 'data-binary = "@%s"\n' "$bodyfile"
      fi
    } | curl -sS -L -o "$out" -w '%{http_code}' --config -
  )" || rc=$?
  [[ -n "$bodyfile" ]] && rm -f "$bodyfile"
  if [[ "$rc" -ne 0 ]]; then
    printf 'curl: request failed\n' >&2
    cat "$out" >&2 2>/dev/null || true
    rm -f "$out"
    return 1
  fi
  if [[ ! "$code" =~ ^2 ]]; then
    msg="$(sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$out" | head -n 1)"
    printf 'HTTP %s: %s\n' "$code" "${msg:-}" >&2
    cat "$out" >&2
    rm -f "$out"
    return 1
  fi
  cat "$out"
  rm -f "$out"
  return 0
}

# Drop nested parent/source/template_repository so sed sees top-level fields only.
json_repo_flat() {
  printf '%s' "$1" | tr '\n' ' ' \
    | sed -E 's/"(parent|source|template_repository)"[[:space:]]*:.*//'
}

# Minimal JSON field helpers (jq when available; else sed for needed keys).
json_str() {
  local json="$1" key="$2"
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    printf '%s' "$json" | jq -r --arg k "$key" 'if .[$k] == null then empty else .[$k]|tostring end'
    return 0
  fi
  json_repo_flat "$json" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

json_bool() {
  local json="$1" key="$2" v
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    v="$(printf '%s' "$json" | jq -r --arg k "$key" '.[$k] | if . == null then empty else tostring end')"
    printf '%s' "$v"
    return 0
  fi
  json_repo_flat "$json" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\\(true\\|false\\).*/\\1/p" | head -n 1
}

json_num() {
  local json="$1" key="$2"
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    printf '%s' "$json" | jq -r --arg k "$key" 'if .[$k] == null then empty else .[$k]|tostring end'
    return 0
  fi
  json_repo_flat "$json" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" | head -n 1
}

json_permissions_admin() {
  local json="$1"
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    printf '%s' "$json" | jq -r '.permissions.admin // false'
    return 0
  fi
  json_repo_flat "$json" \
    | sed -n 's/.*"permissions"[[:space:]]*:[[:space:]]*{[^}]*"admin"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' \
    | head -n 1
}

# JSON string (quoted). jq when available; else escape \ " and controls.
json_str_encode() {
  local s="$1"
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    jq -n --arg s "$s" '$s'
    return 0
  fi
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

api_login() {
  local token="$1" json login
  json="$(api_request "$token" GET user 2>/dev/null)" || return 1
  login="$(json_str "$json" login)"
  [[ -n "$login" && "$login" != null ]] || return 1
  printf '%s' "$login"
}

# Non-interactive git: reset inherited helpers; token via GIT_AUTH_TOKEN env only.
# shellcheck disable=SC2016
git_auth() {
  GCM_INTERACTIVE=never GCM_GUI_PROMPT=false GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS=/bin/false SSH_ASKPASS=/bin/false GH_PROMPT_DISABLED=1 \
    git -c credential.helper= \
    -c credential.https://github.com.helper= \
    -c credential.interactive=false \
    -c core.askPass=/bin/false \
    -c 'credential.helper=!f(){ echo username=x-access-token; echo "password=${GIT_AUTH_TOKEN}"; }; f' \
    "$@"
}

git_source() { GIT_AUTH_TOKEN="$SOURCE_AUTH" git_auth "$@"; }
git_target() { GIT_AUTH_TOKEN="$TARGET_AUTH" git_auth "$@"; }

require_owner_name() {
  [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] \
    || usage_die "$1 is not a valid owner name."
}

require_repo_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] \
    || usage_die "$1 is not a valid repository name."
}

require_owner_repo() {
  [[ "$1" =~ ^[^/]+/[^/]+$ ]] || usage_die "$1 must be owner/repo."
  require_owner_name "${1%%/*}"
  require_repo_name "${1#*/}"
}

parse_args() {
  local positional=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) print_help; exit 0 ;;
      -n|--dry-run) DRY_RUN=1; shift ;;
      -y|--yes) YES=1; shift ;;
      -q|--quiet) QUIET=1; shift ;;
      --mirror)
        [[ "$MODE" == transfer ]] || usage_die "--mirror and --single-commit are mutually exclusive."
        MODE=mirror; shift ;;
      --single-commit)
        [[ "$MODE" == transfer ]] || usage_die "--mirror and --single-commit are mutually exclusive."
        MODE=single-commit; shift ;;
      --branch)
        [[ $# -ge 2 ]] || usage_die "--branch needs a name."
        BRANCHES+=("$2"); shift 2 ;;
      --no-tags) NO_TAGS=1; shift ;;
      --public) TARGET_VISIBILITY=public; shift ;;
      --private) TARGET_VISIBILITY=private; shift ;;
      --host-identity) HOST_IDENTITY=1; shift ;;
      -*) usage_die "Unknown option $1." ;;
      *) positional+=("$1"); shift ;;
    esac
  done
  ((${#positional[@]} >= 1)) || usage_die "Missing <owner/repo>."
  ((${#positional[@]} <= 2)) || usage_die "Unexpected argument ${positional[2]}."
  SOURCE="${positional[0]}"; require_owner_repo "$SOURCE"
  TARGET_NAME="${SOURCE#*/}"
  if ((${#positional[@]} == 2)); then
    local target="${positional[1]}"
    if [[ "$target" == */* ]]; then
      require_owner_repo "$target"
      TARGET_OWNER="${target%%/*}"
      TARGET_NAME="${target#*/}"
    else
      [[ -n "$target" ]] || usage_die "Invalid target-owner."
      require_owner_name "$target"
      TARGET_OWNER="$target"
    fi
  fi
  if ((${#BRANCHES[@]} > 0)) && [[ "$MODE" != mirror ]]; then
    usage_die "--branch requires --mirror."
  fi
  if [[ "$NO_TAGS" -eq 1 && "$MODE" != mirror ]]; then
    usage_die "--no-tags requires --mirror."
  fi
  if [[ -n "$TARGET_VISIBILITY" && "$MODE" == transfer ]]; then
    usage_die "--public/--private apply only to --mirror or --single-commit."
  fi
  if [[ "$HOST_IDENTITY" -eq 1 && "$MODE" != single-commit ]]; then
    usage_die "--host-identity requires --single-commit."
  fi
}

ensure_tools() {
  command -v git >/dev/null 2>&1 || die "git is required but not installed."
  command -v curl >/dev/null 2>&1 || die "curl is required but not installed."
  HAVE_GH=0
  HAVE_JQ=0
  command -v gh >/dev/null 2>&1 && HAVE_GH=1
  command -v jq >/dev/null 2>&1 && HAVE_JQ=1
}

ensure_tools_and_auth() {
  ensure_tools

  SOURCE_AUTH="$(resolve_side_token SOURCE "${SOURCE_TOKEN:-}")" || exit 1
  TARGET_AUTH="$(resolve_side_token TARGET "${TARGET_TOKEN:-}")" || exit 1

  SOURCE_USER="$(api_login "$SOURCE_AUTH" 2>/dev/null || true)"
  TARGET_USER="$(api_login "$TARGET_AUTH" 2>/dev/null || true)"
  if [[ -z "$TARGET_OWNER" ]]; then
    [[ -n "$TARGET_USER" ]] || die "Could not resolve the TARGET user. Set <target-owner>."
    TARGET_OWNER="$TARGET_USER"
  fi
}

confirm() {
  [[ "$DRY_RUN" -eq 1 || "$YES" -eq 1 ]] && return 0
  if ! { : >/dev/tty; } 2>/dev/null; then
    usage_die "Refusing to write without --yes on a non-TTY."
  fi
  local reply prompt target
  target="$(target_slug)"
  case "$MODE" in
    transfer)
      if [[ "$TARGET_NAME" == "${SOURCE#*/}" ]]; then
        prompt="Transfer ${SOURCE} -> ${TARGET_OWNER}? [y/N] "
      else
        prompt="Transfer ${SOURCE} -> ${target}? [y/N] "
      fi
      ;;
    mirror) prompt="Mirror ${SOURCE} -> ${target}? [y/N] " ;;
    single-commit) prompt="Copy ${SOURCE} -> ${target} as a single commit? [y/N] " ;;
  esac
  printf '%s' "$prompt" >/dev/tty
  read -r reply </dev/tty || true
  reply="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')"
  [[ "$reply" == y || "$reply" == yes ]] || die "Aborted."
}

source_meta() {
  local private admin errf meta
  errf="$(mktemp)"
  if ! meta="$(api_request "$SOURCE_AUTH" GET "repos/${SOURCE}" 2>"$errf")"; then
    if grep -qiE 'HTTP 404|HTTP 403|HTTP 401|Not Found|Bad credentials' "$errf"; then
      rm -f "$errf"
      die_repo_inaccessible "$SOURCE"
    fi
    die_from_cmd "Could not read ${SOURCE}" "$errf"
  fi
  rm -f "$errf"
  private="$(json_bool "$meta" private)"
  SOURCE_DEFAULT_BRANCH="$(json_str "$meta" default_branch)"
  admin="$(json_permissions_admin "$meta")"
  [[ -n "$SOURCE_DEFAULT_BRANCH" ]] || die "Could not read the default branch of ${SOURCE}."
  if [[ "$private" == true ]]; then SOURCE_VISIBILITY=private; else SOURCE_VISIBILITY=public; fi
  TARGET_VISIBILITY="${TARGET_VISIBILITY:-$SOURCE_VISIBILITY}"
  ok "source ${SOURCE} (${SOURCE_VISIBILITY})"
  if [[ "$MODE" == transfer && "$admin" != true ]]; then
    warn "no admin rights on ${SOURCE}"
    die "transfer needs admin rights on ${SOURCE}. Use --mirror or --single-commit."
  fi
}

# TARGET_EXISTS=0 free, 1 empty (resume). Dies on non-empty or auth errors.
check_target() {
  local target size refs errf body
  target="$(target_slug)"
  errf="$(mktemp)"
  if body="$(api_request "$TARGET_AUTH" GET "repos/${target}" 2>"$errf")"; then
    rm -f "$errf"
    size="$(json_num "$body" size)"
    refs="$(git_target ls-remote "https://github.com/${target}.git" 2>/dev/null || true)"
    if [[ "${size:-1}" == 0 && -z "$refs" ]]; then
      TARGET_EXISTS=1
      ok "target ${target} exists and is empty (will resume)"
      return 0
    fi
    die "${target} already exists and is not empty."
  fi
  if grep -qE 'HTTP 404' "$errf"; then
    rm -f "$errf"
    TARGET_EXISTS=0
    ok "target ${target} is free"
    return 0
  fi
  if grep -qiE 'HTTP 403|HTTP 401|Bad credentials' "$errf"; then
    rm -f "$errf"
    die_repo_inaccessible "$target"
  fi
  die_from_cmd "Could not check ${target}" "$errf"
}

cleanup() { [[ -n "${TMPDIR_PATH}" && -d "${TMPDIR_PATH}" ]] && rm -rf "${TMPDIR_PATH}"; }

header() {
  local target label
  target="$(target_slug)"
  if [[ "$MODE" == transfer && "$TARGET_NAME" == "${SOURCE#*/}" ]]; then
    label="${MODE} ${SOURCE} -> ${TARGET_OWNER}"
  else
    label="${MODE} ${SOURCE} -> ${target}"
  fi
  [[ "$DRY_RUN" -eq 1 ]] && label="${label} (dry run)"
  out "$label"
}

plan_create_or_reuse() {
  local target i="$1"
  target="$(target_slug)"
  if [[ "$TARGET_EXISTS" -eq 1 ]]; then
    out "  ${i}. Reuse empty ${target}"
  else
    out "  ${i}. Create ${target} (${TARGET_VISIBILITY})"
  fi
}

print_plan() {
  local target i=1
  target="$(target_slug)"
  out "Plan:"
  case "$MODE" in
    transfer)
      if [[ "$TARGET_NAME" != "${SOURCE#*/}" ]]; then
        out "  1. Transfer ${SOURCE} to ${TARGET_OWNER} as ${TARGET_NAME}"
      else
        out "  1. Transfer ${SOURCE} to ${TARGET_OWNER}"
      fi
      out "  2. Wait until ${target} is reachable (up to 60s)"
      ;;
    mirror)
      out "  ${i}. Copy all refs from ${SOURCE}"; i=$((i + 1))
      out "  ${i}. Drop pull-request refs"; i=$((i + 1))
      plan_create_or_reuse "$i"; i=$((i + 1))
      if ((${#BRANCHES[@]} > 0)); then
        out "  ${i}. Push branches: ${BRANCHES[*]}$([[ $NO_TAGS -eq 0 ]] && printf ' + all tags')"
        [[ $NO_TAGS -eq 0 ]] && info "--branch still pushes all tags unless --no-tags"
      elif [[ "$NO_TAGS" -eq 1 ]]; then
        out "  ${i}. Push all branches (no tags)"
      else
        out "  ${i}. Push all refs"
      fi
      out "Note: issues, PRs, releases, wiki, settings, and LFS objects do not move."
      ;;
    single-commit)
      local name email
      {
        read -r name
        read -r email
      } < <(commit_identity)
      out "  ${i}. Copy the default branch of ${SOURCE}"; i=$((i + 1))
      out "  ${i}. Rebuild ${SOURCE_DEFAULT_BRANCH} as one commit (${name} <${email}>)"; i=$((i + 1))
      plan_create_or_reuse "$i"; i=$((i + 1))
      out "  ${i}. Push ${SOURCE_DEFAULT_BRANCH}"
      out "Note: history, issues, PRs, releases, wiki, and settings do not move."
      ;;
  esac
}

ensure_target_repo() {
  local target errf owner_type body private_json path
  target="$(target_slug)"
  if [[ "$TARGET_EXISTS" -eq 1 ]]; then
    out "Resuming into empty ${target}."
    return 0
  fi
  errf="$(mktemp)"
  if ! body="$(api_request "$TARGET_AUTH" GET "users/${TARGET_OWNER}" 2>"$errf")"; then
    if grep -qiE 'HTTP 404|HTTP 403|HTTP 401|Not Found|Bad credentials' "$errf"; then
      rm -f "$errf"
      die_repo_inaccessible "$TARGET_OWNER"
    fi
    die_from_cmd "Could not resolve owner ${TARGET_OWNER}" "$errf"
  fi
  rm -f "$errf"
  owner_type="$(json_str "$body" type)"
  [[ "$TARGET_VISIBILITY" == private ]] && private_json=true || private_json=false
  body="$(printf '{"name":%s,"private":%s}' "$(json_str_encode "$TARGET_NAME")" "$private_json")"
  if [[ "$owner_type" == Organization ]]; then
    path="orgs/${TARGET_OWNER}/repos"
  elif [[ "$owner_type" == User && -n "$TARGET_USER" && "$TARGET_OWNER" == "$TARGET_USER" ]]; then
    path="user/repos"
  else
    die "cannot create ${target} because the TARGET credentials could not be confirmed for ${TARGET_OWNER}."
  fi
  errf="$(mktemp)"
  if ! api_request "$TARGET_AUTH" POST "$path" "$body" >/dev/null 2>"$errf"; then
    die_from_cmd "Could not create ${target}" "$errf"
  fi
  rm -f "$errf"
}

do_transfer() {
  local target errf owner_type waited=0 body
  target="$(target_slug)"
  errf="$(mktemp)"
  if ! body="$(api_request "$SOURCE_AUTH" GET "users/${TARGET_OWNER}" 2>"$errf")"; then
    if grep -qiE 'HTTP 404|HTTP 403|HTTP 401|Not Found|Bad credentials' "$errf"; then
      rm -f "$errf"
      die_repo_inaccessible "$TARGET_OWNER"
    fi
    die_from_cmd "Could not resolve owner ${TARGET_OWNER}" "$errf"
  fi
  rm -f "$errf"
  owner_type="$(json_str "$body" type)"

  if [[ "$TARGET_NAME" != "${SOURCE#*/}" ]]; then
    body="$(printf '{"new_owner":%s,"new_name":%s}' \
      "$(json_str_encode "$TARGET_OWNER")" "$(json_str_encode "$TARGET_NAME")")"
  else
    body="$(printf '{"new_owner":%s}' "$(json_str_encode "$TARGET_OWNER")")"
  fi
  errf="$(mktemp)"
  if ! api_request "$SOURCE_AUTH" POST "repos/${SOURCE}/transfer" "$body" >/dev/null 2>"$errf"; then
    if grep -qiE '422|Validation Failed' "$errf"; then
      die_from_cmd "Transfer of ${SOURCE} failed" "$errf" \
        "Name clash or ${TARGET_OWNER} cannot receive it. Use --mirror or --single-commit."
    fi
    if grep -qiE '403|404|Resource not accessible|Not Found' "$errf"; then
      die_from_cmd "Transfer of ${SOURCE} failed" "$errf" \
        "Use --mirror or --single-commit."
    fi
    die_from_cmd "Transfer of ${SOURCE} failed" "$errf"
  fi
  rm -f "$errf"

  # Personal target: unknown SOURCE login is treated like a different user.
  if [[ "$owner_type" == User && ( -z "$SOURCE_USER" || "$TARGET_OWNER" != "$SOURCE_USER" ) ]]; then
    closing "Transfer requested. ${TARGET_OWNER} must accept it before it completes."
    return 0
  fi

  local poll_max="${GH_REPO_MIGRATE_POLL_MAX:-60}"
  while ((waited < poll_max)); do
    if api_request "$TARGET_AUTH" GET "repos/${target}" >/dev/null 2>&1; then
      closing "Transferred ${SOURCE} to ${target}."
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  warn "timed out waiting for ${target}"
  die "Transfer of ${SOURCE} did not become reachable within ${poll_max}s."
}

drop_pull_refs() {
  local mirror="$1" ref
  while IFS= read -r ref; do
    [[ -n "$ref" ]] && git -C "$mirror" update-ref -d "$ref"
  done < <(git -C "$mirror" for-each-ref --format='%(refname)' refs/pull)
}

# One push of selected refs; remote.origin.mirror must be off for refspecs.
mirror_push_refs() {
  local mirror="$1" target="$2" b refspecs=() ref total=0 errf
  git -C "$mirror" config --unset-all remote.origin.mirror 2>/dev/null || true
  if ((${#BRANCHES[@]} > 0)); then
    for b in "${BRANCHES[@]}"; do
      git -C "$mirror" show-ref --verify --quiet "refs/heads/${b}" \
        || die "Branch '${b}' does not exist in the source."
      refspecs+=("refs/heads/${b}:refs/heads/${b}")
    done
    if [[ "$NO_TAGS" -eq 0 ]]; then
      while IFS= read -r ref; do
        [[ -n "$ref" ]] && refspecs+=("${ref}:${ref}")
      done < <(git -C "$mirror" for-each-ref --format='%(refname)' refs/tags)
    fi
  elif [[ "$NO_TAGS" -eq 1 ]]; then
    while IFS= read -r ref; do
      [[ -n "$ref" ]] && refspecs+=("${ref}:${ref}")
    done < <(git -C "$mirror" for-each-ref --format='%(refname)' refs/heads)
  else
    total="$(git -C "$mirror" for-each-ref --format='%(refname)' refs/heads refs/tags | wc -l | tr -d ' ')"
    out "  Pushing to ${target} ..."
    errf="$(mktemp)"
    if ! git_target -C "$mirror" push --mirror "https://github.com/${target}.git" 2>"$errf"; then
      die_from_cmd "Push to ${target} failed" "$errf"
    fi
    rm -f "$errf"
    out "  pushed: ${total}/${total} refs"
    return 0
  fi
  total=${#refspecs[@]}
  out "  Pushing to ${target} ..."
  errf="$(mktemp)"
  if ! git_target -C "$mirror" push "https://github.com/${target}.git" "${refspecs[@]}" 2>"$errf"; then
    die_from_cmd "Push to ${target} failed" "$errf"
  fi
  rm -f "$errf"
  out "  pushed: ${total}/${total} refs"
}

do_mirror() {
  local target mirror branches_n tags_n attrs errf
  target="$(target_slug)"
  TMPDIR_PATH="$(mktemp -d)"
  trap cleanup EXIT
  mirror="${TMPDIR_PATH}/mirror.git"
  out "  Cloning ${SOURCE} ..."
  errf="$(mktemp)"
  if ! git_source clone --mirror "https://github.com/${SOURCE}.git" "$mirror" 2>"$errf"; then
    die_from_cmd "Clone of ${SOURCE} failed" "$errf"
  fi
  rm -f "$errf"
  drop_pull_refs "$mirror"
  attrs="$(git -C "$mirror" show HEAD:.gitattributes 2>/dev/null || true)"
  if [[ "$attrs" == *filter=lfs* ]]; then
    warn "source uses Git LFS; LFS objects are not copied"
  fi
  branches_n="$(git -C "$mirror" for-each-ref --format='%(refname)' refs/heads | wc -l | tr -d ' ')"
  tags_n="$(git -C "$mirror" for-each-ref --format='%(refname)' refs/tags | wc -l | tr -d ' ')"
  out "  source: ${branches_n} branches, ${tags_n} tags"
  if ((${#BRANCHES[@]} > 0)) && [[ "$NO_TAGS" -eq 0 ]]; then
    info "--branch still pushes all tags unless --no-tags"
  fi
  ensure_target_repo
  mirror_push_refs "$mirror" "$target"
  closing "Mirrored ${SOURCE} to ${target}."
}

commit_identity() {
  local name email
  if [[ "$HOST_IDENTITY" -eq 1 ]]; then
    name="$(git config --get user.name 2>/dev/null || true)"
    email="$(git config --get user.email 2>/dev/null || true)"
    [[ -n "$name" && -n "$email" ]] \
      || die "git user.name and user.email are required with --host-identity."
  else
    name=gh-repo-migrate
    email=gh-repo-migrate@users.noreply.github.com
  fi
  printf '%s\n%s\n' "$name" "$email"
}

do_single() {
  local target source_dir sha name email attrs errf when
  target="$(target_slug)"
  TMPDIR_PATH="$(mktemp -d)"
  trap cleanup EXIT
  source_dir="${TMPDIR_PATH}/source.git"
  out "  Cloning ${SOURCE} ..."
  errf="$(mktemp)"
  if ! git_source clone --bare --depth 1 --branch "$SOURCE_DEFAULT_BRANCH" \
    "https://github.com/${SOURCE}.git" "$source_dir" 2>"$errf"; then
    die_from_cmd "Clone of ${SOURCE} failed" "$errf"
  fi
  rm -f "$errf"
  if git -C "$source_dir" show HEAD:.gitmodules >/dev/null 2>&1; then
    warn ".gitmodules present; submodules are not initialized"
  fi
  attrs="$(git -C "$source_dir" show HEAD:.gitattributes 2>/dev/null || true)"
  if [[ "$attrs" == *filter=lfs* ]]; then
    warn ".gitattributes uses filter=lfs; LFS objects are not copied"
  fi
  {
    read -r name
    read -r email
  } < <(commit_identity)
  when="$(date -u +"%Y-%m-%d %H:%M:%S +0000")"
  errf="$(mktemp)"
  if ! sha="$(
    GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" \
      GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" \
      GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" \
      git -C "$source_dir" commit-tree "HEAD^{tree}" -m "Initial commit" 2>"$errf"
  )"; then
    die_from_cmd "Could not create the single commit" "$errf"
  fi
  rm -f "$errf"
  ensure_target_repo
  out "  Pushing to ${target} ..."
  errf="$(mktemp)"
  if ! git_target -C "$source_dir" push "https://github.com/${target}.git" \
    "${sha}:refs/heads/${SOURCE_DEFAULT_BRANCH}" 2>"$errf"; then
    die_from_cmd "Push of ${SOURCE_DEFAULT_BRANCH} to ${target} failed" "$errf"
  fi
  rm -f "$errf"
  closing "Copied ${SOURCE} to ${target} as a single commit."
}

main() {
  parse_args "$@"
  ensure_tools_and_auth
  header
  if [[ -n "$SOURCE_USER" && -n "$TARGET_USER" ]]; then
    ok "authenticated (SOURCE: ${SOURCE_USER}, TARGET: ${TARGET_USER})"
  else
    ok "authenticated"
  fi

  source_meta
  if [[ "$(target_slug)" == "$SOURCE" ]]; then
    usage_die "Source and target must differ."
  fi
  check_target
  if [[ "$MODE" == transfer && "$TARGET_EXISTS" -eq 1 ]]; then
    die "$(target_slug) already exists."
  fi

  print_plan
  if [[ "$DRY_RUN" -eq 1 ]]; then
    closing "Dry run: nothing changed."
    exit 0
  fi
  confirm
  case "$MODE" in
    transfer) do_transfer ;;
    mirror) do_mirror ;;
    single-commit) do_single ;;
  esac
}

main "$@"
