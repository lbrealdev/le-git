#!/usr/bin/env bash
# Write: move a GitHub repository (transfer, mirror, or single commit).

set -euo pipefail

MODE=transfer
DRY_RUN=0
YES=0
QUIET=0
VERBOSE=0
VISIBILITY=''
NO_TAGS=0
SOURCE=''
DEST_OWNER=''
DEST_NAME=''
AUTH_USER=''
SRC_VIS=''
SRC_DEFAULT=''
DEST_EXISTS=0
TMPDIR_PATH=''
BRANCHES=()

USE_COLOR=0
[[ -t 1 && -z "${NO_COLOR:-}" ]] && USE_COLOR=1

c() {
  [[ "$USE_COLOR" -eq 1 ]] || return 0
  case "$1" in green) printf '\033[32m' ;; yellow) printf '\033[33m' ;;
    dim) printf '\033[2m' ;; reset) printf '\033[0m' ;; esac
}
out() { [[ "$QUIET" -eq 1 ]] || printf '%s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }
die() { err "$1"; exit 1; }
usage_die() { err "$1 Try --help."; exit 2; }
ok() { out "  $(c green)ok$(c reset)  $1"; }
warn() { out "  $(c yellow)warn$(c reset)  $*"; }
step_cmd() { [[ "$VERBOSE" -eq 1 ]] && out "      $(c dim)$*$(c reset)" || true; }
dest_slug() { printf '%s/%s' "$DEST_OWNER" "$DEST_NAME"; }

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate.sh <owner/repo> [<new-owner>[/<name>]] [options]

Move a GitHub repository to another owner (transfer, mirror, or single commit).

Modes:
  (default)           Native transfer (requires admin on the source)
  --mirror            Clone --mirror and push to a new destination repo
  --single-commit     Copy the default branch as one fresh commit

Options:
  --branch <name>     With --mirror: push only these branches (repeatable)
  --no-tags           With --mirror: do not push tags
  --public            Destination visibility (mirror / single-commit)
  --private           Destination visibility (mirror / single-commit)
  -n, --dry-run       Show plan; change nothing
  -y, --yes           Skip confirmation prompt
  -q, --quiet         Hide non-error stdout
  -v, --verbose       Show the command under each plan step
  -h, --help          Show this help and exit

Environment:
  GH_TOKEN            Token for gh (preferred)
  GITHUB_TOKEN        Used as GH_TOKEN when GH_TOKEN is unset
  NO_COLOR            Disable colour when set

Notes:
  Transfer needs admin on the source. Mirror and single-commit create a
  new repo (or resume an empty one). Issues, PRs, releases, wiki, and
  settings are not moved by mirror or single-commit. LFS objects are not
  copied. Tokens never appear in argv, URLs, or git config.

Exit codes:
  0  Success
  1  Runtime failure
  2  Usage error

Examples:
  ./scripts/gh-repo-migrate.sh acme/widget new-co
  ./scripts/gh-repo-migrate.sh acme/widget new-co/widget --mirror -n
  ./scripts/gh-repo-migrate.sh acme/widget --single-commit --public -y
  ./scripts/gh-repo-migrate.sh acme/widget new-co --mirror --branch main
EOF
}

# Non-interactive git via gh credentials (no GCM popup, no token in argv).
git_gh() {
  GCM_INTERACTIVE=never GIT_TERMINAL_PROMPT=0 \
    git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"
}

require_owner_repo() {
  [[ "$1" =~ ^[^/]+/[^/]+$ ]] || usage_die "'$1' must be owner/repo."
}

parse_args() {
  local positional=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) print_help; exit 0 ;;
      -n|--dry-run) DRY_RUN=1; shift ;;
      -y|--yes) YES=1; shift ;;
      -q|--quiet) QUIET=1; shift ;;
      -v|--verbose) VERBOSE=1; shift ;;
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
      --public) VISIBILITY=public; shift ;;
      --private) VISIBILITY=private; shift ;;
      -*) usage_die "Unknown option: $1." ;;
      *) positional+=("$1"); shift ;;
    esac
  done
  ((${#positional[@]} >= 1)) || usage_die "Missing <owner/repo>."
  ((${#positional[@]} <= 2)) || usage_die "Unexpected argument: ${positional[2]}."
  SOURCE="${positional[0]}"; require_owner_repo "$SOURCE"
  DEST_NAME="${SOURCE#*/}"
  if ((${#positional[@]} == 2)); then
    local dest="${positional[1]}"
    if [[ "$dest" == */* ]]; then
      require_owner_repo "$dest"; DEST_OWNER="${dest%%/*}"; DEST_NAME="${dest#*/}"
    else
      [[ -n "$dest" ]] || usage_die "Invalid new-owner."; DEST_OWNER="$dest"
    fi
  fi
  if ((${#BRANCHES[@]} > 0)) && [[ "$MODE" != mirror ]]; then
    usage_die "--branch requires --mirror."
  fi
  if [[ "$NO_TAGS" -eq 1 && "$MODE" != mirror ]]; then
    usage_die "--no-tags requires --mirror."
  fi
  if [[ -n "$VISIBILITY" && "$MODE" == transfer ]]; then
    usage_die "--public/--private apply only to --mirror or --single-commit."
  fi
}

resolve_auth_user() {
  local login
  login="$(gh api user --jq .login 2>/dev/null || true)"
  if [[ -z "$login" ]]; then
    login="$(gh api graphql -f query='{viewer{login}}' --jq .data.viewer.login 2>/dev/null || true)"
  fi
  if [[ -z "$login" ]]; then
    login="$(
      gh auth status 2>&1 | awk '/Logged in to .* account / {
        for (i = 1; i <= NF; i++) if ($i == "account") { print $(i + 1); exit }
      }'
    )"
  fi
  printf '%s' "$login"
}

ensure_tools_and_auth() {
  command -v gh >/dev/null 2>&1 || die "gh not found (https://cli.github.com)"
  command -v git >/dev/null 2>&1 || die "git not found"
  if [[ -z "${GH_TOKEN:-}" && -n "${GITHUB_TOKEN:-}" ]]; then export GH_TOKEN="$GITHUB_TOKEN"; fi
  if [[ -z "${GH_TOKEN:-}" ]]; then
    gh auth status >/dev/null 2>&1 || die "no token and gh is not logged in"
  fi
  AUTH_USER="$(resolve_auth_user)"
  if [[ -z "$DEST_OWNER" ]]; then
    [[ -n "$AUTH_USER" ]] || die "could not resolve authenticated user"
    DEST_OWNER="$AUTH_USER"
  fi
}

confirm() {
  [[ "$DRY_RUN" -eq 1 || "$YES" -eq 1 ]] && return 0
  [[ -r /dev/tty ]] || usage_die "Refusing to write without --yes on a non-TTY."
  local reply=
  printf 'Proceed? [y/N] ' >/dev/tty
  read -r reply </dev/tty || true
  [[ "$reply" == [yY] || "$reply" == yes || "$reply" == YES ]] || die "aborted"
}

src_meta() {
  local private
  private="$(gh api "repos/${SOURCE}" --jq .private)" || die "cannot read source ${SOURCE}"
  if [[ "$private" == true ]]; then SRC_VIS=private; else SRC_VIS=public; fi
  SRC_DEFAULT="$(gh api "repos/${SOURCE}" --jq .default_branch)" \
    || die "cannot read default branch of ${SOURCE}"
  VISIBILITY="${VISIBILITY:-$SRC_VIS}"
  ok "source ${SOURCE} (${SRC_VIS})"
}

check_dest() {
  local dest size refs errf; dest="$(dest_slug)"; errf="$(mktemp)"
  if gh api "repos/${dest}" >"$errf" 2>&1; then
    size="$(gh api "repos/${dest}" --jq .size)"
    refs="$(git_gh ls-remote "https://github.com/${dest}.git" 2>/dev/null || true)"
    rm -f "$errf"
    if [[ "$size" == 0 && -z "$refs" ]]; then
      DEST_EXISTS=1; ok "dest ${dest} exists and is empty (will resume)"; return 0
    fi
    die "destination ${dest} already exists and is not empty"
  fi
  if grep -qiE 'HTTP 403|HTTP 401|Bad credentials|rate limit' "$errf"; then
    cat "$errf" >&2; rm -f "$errf"; die "cannot check destination ${dest}"
  fi
  rm -f "$errf"; DEST_EXISTS=0; ok "dest ${dest} is free"
}

cleanup() { [[ -n "${TMPDIR_PATH}" && -d "${TMPDIR_PATH}" ]] && rm -rf "${TMPDIR_PATH}"; }

header() {
  local dest label; dest="$(dest_slug)"
  if [[ "$MODE" == transfer && "$DEST_NAME" == "${SOURCE#*/}" ]]; then
    label="${MODE} ${SOURCE} -> ${DEST_OWNER}"
  else
    label="${MODE} ${SOURCE} -> ${dest}"
  fi
  [[ "$DRY_RUN" -eq 1 ]] && label="${label} (dry run)"
  out "$label"
}

print_plan() {
  local dest i=1 vis_flag
  dest="$(dest_slug)"
  [[ "$VISIBILITY" == public ]] && vis_flag=--public || vis_flag=--private
  out "Plan:"
  case "$MODE" in
    transfer)
      if [[ "$DEST_NAME" != "${SOURCE#*/}" ]]; then
        out "  1. Transfer ${SOURCE} to ${DEST_OWNER} as ${DEST_NAME}"
        step_cmd "gh api -X POST repos/${SOURCE}/transfer -f new_owner=${DEST_OWNER} -f new_name=${DEST_NAME}"
      else
        out "  1. Transfer ${SOURCE} to ${DEST_OWNER}"
        step_cmd "gh api -X POST repos/${SOURCE}/transfer -f new_owner=${DEST_OWNER}"
      fi
      out "  2. Wait until ${dest} is reachable (up to 60s)"
      step_cmd "poll gh api repos/${dest} (up to 60s)"
      ;;
    mirror)
      out "  ${i}. Mirror-clone ${SOURCE}"; step_cmd "git clone --mirror https://github.com/${SOURCE}.git"; i=$((i + 1))
      out "  ${i}. Drop refs/pull/*"; step_cmd "git update-ref -d refs/pull/*"; i=$((i + 1))
      if [[ "$DEST_EXISTS" -eq 1 ]]; then
        out "  ${i}. Reuse empty ${dest}"
      else
        out "  ${i}. Create ${dest} (${VISIBILITY})"
        step_cmd "gh repo create ${dest} ${vis_flag}"
      fi
      i=$((i + 1))
      if ((${#BRANCHES[@]} > 0)); then
        out "  ${i}. Push branches: ${BRANCHES[*]}$([[ $NO_TAGS -eq 0 ]] && printf ' + tags')"
        step_cmd "git push origin refs/heads/<branch> [ --tags ]"
      elif [[ "$NO_TAGS" -eq 1 ]]; then
        out "  ${i}. Push all heads (no tags)"
        step_cmd "git push origin 'refs/heads/*:refs/heads/*'"
      else
        out "  ${i}. Push --mirror"
        step_cmd "git push --mirror"
      fi
      out "Note: issues, PRs, releases, wiki, settings, and LFS objects do not move."
      ;;
    single-commit)
      out "  ${i}. Shallow-clone default branch of ${SOURCE}"
      step_cmd "git clone --depth 1 --branch ${SRC_DEFAULT} https://github.com/${SOURCE}.git"
      i=$((i + 1))
      out "  ${i}. Rebuild as one commit on ${SRC_DEFAULT}"
      step_cmd "git init -b ${SRC_DEFAULT} && git add -A --force && git commit"
      i=$((i + 1))
      if [[ "$DEST_EXISTS" -eq 1 ]]; then
        out "  ${i}. Reuse empty ${dest}"
      else
        out "  ${i}. Create ${dest} (${VISIBILITY})"
        step_cmd "gh repo create ${dest} ${vis_flag}"
      fi
      i=$((i + 1))
      out "  ${i}. Push ${SRC_DEFAULT}"
      step_cmd "git push -u origin ${SRC_DEFAULT}"
      out "Note: history, issues, PRs, releases, wiki, and settings do not move."
      ;;
  esac
}

ensure_dest_repo() {
  local dest vis_flag; dest="$(dest_slug)"
  if [[ "$DEST_EXISTS" -eq 1 ]]; then out "Resuming into empty ${dest}."; return 0; fi
  [[ "$VISIBILITY" == public ]] && vis_flag=--public || vis_flag=--private
  gh repo create "$dest" "$vis_flag" >/dev/null
}

do_transfer() {
  local dest args=() errf owner_type waited=0; dest="$(dest_slug)"
  args=(-X POST "repos/${SOURCE}/transfer" -f "new_owner=${DEST_OWNER}")
  [[ "$DEST_NAME" != "${SOURCE#*/}" ]] && args+=(-f "new_name=${DEST_NAME}")
  errf="$(mktemp)"
  if ! gh api "${args[@]}" >/dev/null 2>"$errf"; then
    if grep -qiE '403|404|422|Resource not accessible|Not Found|Validation Failed' "$errf"; then
      cat "$errf" >&2; rm -f "$errf"
      die "transfer failed (need admin on ${SOURCE}). Try --mirror or --single-commit."
    fi
    cat "$errf" >&2; rm -f "$errf"; die "transfer failed"
  fi
  rm -f "$errf"
  while ((waited < 60)); do
    gh api "repos/${dest}" >/dev/null 2>&1 && break
    sleep 2; waited=$((waited + 2))
  done
  owner_type="$(gh api "users/${DEST_OWNER}" --jq .type 2>/dev/null || echo Organization)"
  if [[ "$owner_type" == User && "$DEST_OWNER" != "$AUTH_USER" ]]; then
    out "Transfer requested. ${DEST_OWNER} must accept it before it completes."
  else
    out "Transferred ${SOURCE} to ${dest}."
  fi
}

drop_pull_refs() {
  local mirror="$1" ref
  while IFS= read -r ref; do
    [[ -n "$ref" ]] && git -C "$mirror" update-ref -d "$ref"
  done < <(git -C "$mirror" for-each-ref --format='%(refname)' refs/pull)
}

do_mirror() {
  local dest mirror branches_n tags_n b
  dest="$(dest_slug)"; TMPDIR_PATH="$(mktemp -d)"; trap cleanup EXIT
  mirror="${TMPDIR_PATH}/mirror.git"
  git_gh clone --mirror "https://github.com/${SOURCE}.git" "$mirror"
  drop_pull_refs "$mirror"
  if git -C "$mirror" show HEAD:.gitattributes 2>/dev/null | grep -q 'filter=lfs'; then
    warn "source uses Git LFS; LFS objects are not copied"
  fi
  branches_n="$(git -C "$mirror" for-each-ref --format='%(refname)' refs/heads | wc -l | tr -d ' ')"
  tags_n="$(git -C "$mirror" for-each-ref --format='%(refname)' refs/tags | wc -l | tr -d ' ')"
  out "  branches: ${branches_n}  tags: ${tags_n}"
  ensure_dest_repo
  git -C "$mirror" remote set-url origin "https://github.com/${dest}.git"
  if ((${#BRANCHES[@]} > 0)); then
    for b in "${BRANCHES[@]}"; do
      git -C "$mirror" show-ref --verify --quiet "refs/heads/${b}" \
        || die "branch '${b}' does not exist in source"
      git_gh -C "$mirror" push origin "refs/heads/${b}"
    done
    if [[ "$NO_TAGS" -eq 0 ]]; then
      git_gh -C "$mirror" push origin --tags
    fi
  elif [[ "$NO_TAGS" -eq 1 ]]; then
    git_gh -C "$mirror" push origin 'refs/heads/*:refs/heads/*'
  else
    git_gh -C "$mirror" push --mirror origin
  fi
  out "Mirrored ${SOURCE} to ${dest}."
}

do_single() {
  local dest srcdir; dest="$(dest_slug)"
  TMPDIR_PATH="$(mktemp -d)"; trap cleanup EXIT; srcdir="${TMPDIR_PATH}/src"
  git_gh clone --depth 1 --branch "$SRC_DEFAULT" \
    "https://github.com/${SOURCE}.git" "$srcdir"
  if [[ -f "${srcdir}/.gitmodules" ]]; then
    warn ".gitmodules present; submodules are not initialized"
  fi
  if [[ -f "${srcdir}/.gitattributes" ]] && grep -q 'filter=lfs' "${srcdir}/.gitattributes"; then
    warn ".gitattributes uses filter=lfs; LFS objects are not copied"
  fi
  rm -rf "${srcdir}/.git"
  git -C "$srcdir" init -b "$SRC_DEFAULT"
  git -C "$srcdir" add -A --force
  git -C "$srcdir" -c user.email=gh-repo-migrate@localhost \
    -c user.name=gh-repo-migrate commit --allow-empty -m "Initial commit" >/dev/null
  ensure_dest_repo
  git -C "$srcdir" remote add origin "https://github.com/${dest}.git"
  git_gh -C "$srcdir" push -u origin "$SRC_DEFAULT"
  out "Copied ${SOURCE} to ${dest} as a single commit."
}

main() {
  parse_args "$@"
  ensure_tools_and_auth
  header
  ok "gh authenticated"
  src_meta
  if [[ "$(dest_slug)" == "$SOURCE" ]]; then
    usage_die "source and destination must differ."
  fi
  if [[ "$MODE" == transfer ]]; then
    if gh api "repos/$(dest_slug)" >/dev/null 2>&1; then
      die "destination $(dest_slug) already exists"
    fi
    ok "dest $(dest_slug) is free"
  else
    check_dest
  fi
  print_plan
  if [[ "$DRY_RUN" -eq 1 ]]; then
    out "Dry run: nothing changed."
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
