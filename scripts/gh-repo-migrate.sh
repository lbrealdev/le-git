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

out() { [[ "$QUIET" -eq 1 ]] || printf '%s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }
die() { err "$1"; exit 1; }
usage_die() { err "$1 Try --help."; exit 2; }
ok() { out "  ok  $1"; }
warn() { out "  !!  $*"; }
info() { out "  i   $*"; }
step_cmd() { [[ "$VERBOSE" -eq 1 ]] && info "$*" || true; }
dest_slug() { printf '%s/%s' "$DEST_OWNER" "$DEST_NAME"; }

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate.sh <owner/repo> [<new-owner>[/<name>]] [options]

Move a GitHub repository to another owner (transfer, mirror, or single commit).
Auth: GH_TOKEN or GITHUB_TOKEN, else gh auth login.

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

Examples:
  ./scripts/gh-repo-migrate.sh acme/widget new-co
  ./scripts/gh-repo-migrate.sh acme/widget new-co --mirror --branch main
  ./scripts/gh-repo-migrate.sh acme/widget --single-commit -n
EOF
}

# Non-interactive git via gh credentials (no GCM popup, no token in argv).
git_gh() {
  GCM_INTERACTIVE=never GIT_TERMINAL_PROMPT=0 \
    git -c credential.helper= \
    -c credential.https://github.com.helper= \
    -c credential.interactive=false \
    -c 'credential.helper=!gh auth git-credential' "$@"
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

ensure_tools_and_auth() {
  command -v gh >/dev/null 2>&1 || die "gh not found (https://cli.github.com)"
  command -v git >/dev/null 2>&1 || die "git not found"
  if [[ -z "${GH_TOKEN:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
    export GH_TOKEN="$GITHUB_TOKEN"
  fi
  if [[ -z "${GH_TOKEN:-}" ]]; then
    gh auth status >/dev/null 2>&1 || die "no token and gh is not logged in"
  fi
  AUTH_USER="$(gh api user --jq .login 2>/dev/null || true)"
  if [[ -z "$AUTH_USER" ]]; then
    AUTH_USER="$(gh api graphql -f query='{viewer{login}}' --jq .data.viewer.login 2>/dev/null || true)"
  fi
  if [[ -z "$DEST_OWNER" ]]; then
    [[ -n "$AUTH_USER" ]] || die "could not resolve authenticated user"
    DEST_OWNER="$AUTH_USER"
  fi
}

confirm() {
  [[ "$DRY_RUN" -eq 1 || "$YES" -eq 1 ]] && return 0
  if ! { : >/dev/tty; } 2>/dev/null; then
    usage_die "Refusing to write without --yes on a non-TTY."
  fi
  local reply prompt dest
  dest="$(dest_slug)"
  case "$MODE" in
    transfer)
      if [[ "$DEST_NAME" == "${SOURCE#*/}" ]]; then
        prompt="Transfer ${SOURCE} -> ${DEST_OWNER}? [y/N] "
      else
        prompt="Transfer ${SOURCE} -> ${dest}? [y/N] "
      fi
      ;;
    mirror) prompt="Mirror ${SOURCE} -> ${dest}? [y/N] " ;;
    single-commit) prompt="Copy ${SOURCE} -> ${dest} as a single commit? [y/N] " ;;
  esac
  printf '%s' "$prompt" >/dev/tty
  read -r reply </dev/tty || true
  reply="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')"
  [[ "$reply" == y || "$reply" == yes ]] || die "aborted"
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

# DEST_EXISTS=0 free, 1 empty (resume). Dies on non-empty or auth errors.
check_dest() {
  local dest size refs errf
  dest="$(dest_slug)"
  errf="$(mktemp)"
  if gh api "repos/${dest}" >"$errf" 2>&1; then
    size="$(gh api "repos/${dest}" --jq .size)" || true
    refs="$(git_gh ls-remote "https://github.com/${dest}.git" 2>/dev/null || true)"
    rm -f "$errf"
    if [[ "${size:-1}" == 0 && -z "$refs" ]]; then
      DEST_EXISTS=1
      ok "dest ${dest} exists and is empty (will resume)"
      return 0
    fi
    die "destination ${dest} already exists and is not empty"
  fi
  if grep -qiE 'HTTP 403|HTTP 401|Bad credentials|rate limit' "$errf"; then
    cat "$errf" >&2
    rm -f "$errf"
    die "cannot check destination ${dest}"
  fi
  rm -f "$errf"
  DEST_EXISTS=0
  ok "dest ${dest} is free"
}

cleanup() { [[ -n "${TMPDIR_PATH}" && -d "${TMPDIR_PATH}" ]] && rm -rf "${TMPDIR_PATH}"; }

header() {
  local dest label
  dest="$(dest_slug)"
  if [[ "$MODE" == transfer && "$DEST_NAME" == "${SOURCE#*/}" ]]; then
    label="${MODE} ${SOURCE} -> ${DEST_OWNER}"
  else
    label="${MODE} ${SOURCE} -> ${dest}"
  fi
  [[ "$DRY_RUN" -eq 1 ]] && label="${label} (dry run)"
  out "$label"
}

plan_create_or_reuse() {
  local dest i="$1" vis_flag
  dest="$(dest_slug)"
  [[ "$VISIBILITY" == public ]] && vis_flag=--public || vis_flag=--private
  if [[ "$DEST_EXISTS" -eq 1 ]]; then
    out "  ${i}. Reuse empty ${dest}"
  else
    out "  ${i}. Create ${dest} (${VISIBILITY})"
    step_cmd "gh repo create ${dest} ${vis_flag}"
  fi
}

print_plan() {
  local dest i=1
  dest="$(dest_slug)"
  out "Plan:"
  case "$MODE" in
    transfer)
      if [[ "$DEST_NAME" != "${SOURCE#*/}" ]]; then
        out "  1. Transfer ${SOURCE} to ${DEST_OWNER} as ${DEST_NAME}"
      else
        out "  1. Transfer ${SOURCE} to ${DEST_OWNER}"
      fi
      out "  2. Wait until ${dest} is reachable (up to 60s)"
      ;;
    mirror)
      out "  ${i}. Mirror-clone ${SOURCE}"; i=$((i + 1))
      out "  ${i}. Drop refs/pull/*"; i=$((i + 1))
      plan_create_or_reuse "$i"; i=$((i + 1))
      if ((${#BRANCHES[@]} > 0)); then
        out "  ${i}. Push branches: ${BRANCHES[*]}$([[ $NO_TAGS -eq 0 ]] && printf ' + all tags')"
        [[ $NO_TAGS -eq 0 ]] && info "--branch still pushes all tags unless --no-tags"
      elif [[ "$NO_TAGS" -eq 1 ]]; then
        out "  ${i}. Push all heads (no tags)"
      else
        out "  ${i}. Push --mirror"
      fi
      out "Note: issues, PRs, releases, wiki, settings, and LFS objects do not move."
      ;;
    single-commit)
      out "  ${i}. Shallow-clone default branch of ${SOURCE}"; i=$((i + 1))
      out "  ${i}. commit-tree HEAD^{tree} on ${SRC_DEFAULT}"; i=$((i + 1))
      plan_create_or_reuse "$i"; i=$((i + 1))
      out "  ${i}. Push ${SRC_DEFAULT}"
      out "Note: history, issues, PRs, releases, wiki, and settings do not move."
      ;;
  esac
}

ensure_dest_repo() {
  local dest vis_flag
  dest="$(dest_slug)"
  if [[ "$DEST_EXISTS" -eq 1 ]]; then
    out "Resuming into empty ${dest}."
    return 0
  fi
  [[ "$VISIBILITY" == public ]] && vis_flag=--public || vis_flag=--private
  gh repo create "$dest" "$vis_flag" >/dev/null || die "failed to create ${dest}"
}

do_transfer() {
  local dest args=() errf owner_type waited=0
  dest="$(dest_slug)"
  owner_type="$(gh api "users/${DEST_OWNER}" --jq .type)" \
    || die "cannot resolve owner type for ${DEST_OWNER}"

  args=(-X POST "repos/${SOURCE}/transfer" -f "new_owner=${DEST_OWNER}")
  [[ "$DEST_NAME" != "${SOURCE#*/}" ]] && args+=(-f "new_name=${DEST_NAME}")
  errf="$(mktemp)"
  if ! gh api "${args[@]}" >/dev/null 2>"$errf"; then
    if grep -qiE '422|Validation Failed' "$errf"; then
      cat "$errf" >&2
      rm -f "$errf"
      die "transfer failed: name clash or ${DEST_OWNER} cannot receive it. Try --mirror or --single-commit."
    fi
    if grep -qiE '403|404|Resource not accessible|Not Found' "$errf"; then
      cat "$errf" >&2
      rm -f "$errf"
      die "transfer failed (need admin on ${SOURCE}). Try --mirror or --single-commit."
    fi
    cat "$errf" >&2
    rm -f "$errf"
    die "transfer failed"
  fi
  rm -f "$errf"

  if [[ "$owner_type" == User && "$DEST_OWNER" != "$AUTH_USER" ]]; then
    out "Transfer requested. ${DEST_OWNER} must accept it before it completes."
    return 0
  fi

  local poll_max="${GH_REPO_MIGRATE_POLL_MAX:-60}"
  while ((waited < poll_max)); do
    if gh api "repos/${dest}" >/dev/null 2>&1; then
      out "Transferred ${SOURCE} to ${dest}."
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  warn "timed out waiting for ${dest}"
  die "transfer of ${SOURCE} did not become reachable within ${poll_max}s"
}

drop_pull_refs() {
  local mirror="$1" ref
  while IFS= read -r ref; do
    [[ -n "$ref" ]] && git -C "$mirror" update-ref -d "$ref"
  done < <(git -C "$mirror" for-each-ref --format='%(refname)' refs/pull)
}

# One push of selected refs; remote.origin.mirror must be off for refspecs.
mirror_push_refs() {
  local mirror="$1" dest="$2" b refspecs=() ref total=0
  git -C "$mirror" config --unset-all remote.origin.mirror 2>/dev/null || true
  if ((${#BRANCHES[@]} > 0)); then
    for b in "${BRANCHES[@]}"; do
      git -C "$mirror" show-ref --verify --quiet "refs/heads/${b}" \
        || die "branch '${b}' does not exist in source"
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
    git_gh -C "$mirror" push --mirror "https://github.com/${dest}.git" \
      || die "failed to mirror-push to ${dest}"
    out "  pushed: ${total}/${total} refs"
    return 0
  fi
  total=${#refspecs[@]}
  git_gh -C "$mirror" push "https://github.com/${dest}.git" "${refspecs[@]}" \
    || die "failed to push selected refs to ${dest}"
  out "  pushed: ${total}/${total} refs"
}

do_mirror() {
  local dest mirror branches_n tags_n attrs
  dest="$(dest_slug)"
  TMPDIR_PATH="$(mktemp -d)"
  trap cleanup EXIT
  mirror="${TMPDIR_PATH}/mirror.git"
  git_gh clone --mirror "https://github.com/${SOURCE}.git" "$mirror" \
    || die "failed to mirror-clone ${SOURCE}"
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
  ensure_dest_repo
  mirror_push_refs "$mirror" "$dest"
  out "Mirrored ${SOURCE} to ${dest}."
}

commit_identity() {
  local name email
  name="$(git config --get user.name 2>/dev/null || true)"
  email="$(git config --get user.email 2>/dev/null || true)"
  [[ -n "$name" ]] || name=gh-repo-migrate
  [[ -n "$email" ]] || email=gh-repo-migrate@localhost
  printf '%s\n%s\n' "$name" "$email"
}

do_single() {
  local dest srcdir sha name email attrs
  dest="$(dest_slug)"
  TMPDIR_PATH="$(mktemp -d)"
  trap cleanup EXIT
  srcdir="${TMPDIR_PATH}/src"
  git_gh clone --depth 1 --branch "$SRC_DEFAULT" \
    "https://github.com/${SOURCE}.git" "$srcdir" \
    || die "failed to clone ${SOURCE}"
  if [[ -f "${srcdir}/.gitmodules" ]]; then
    warn ".gitmodules present; submodules are not initialized"
  fi
  attrs="$(cat "${srcdir}/.gitattributes" 2>/dev/null || true)"
  if [[ "$attrs" == *filter=lfs* ]]; then
    warn ".gitattributes uses filter=lfs; LFS objects are not copied"
  fi
  {
    read -r name
    read -r email
  } < <(commit_identity)
  sha="$(
    git -C "$srcdir" -c user.name="$name" -c user.email="$email" \
      commit-tree "HEAD^{tree}" -m "Initial commit"
  )" || die "failed to create commit-tree"
  ensure_dest_repo
  git_gh -C "$srcdir" push "https://github.com/${dest}.git" \
    "${sha}:refs/heads/${SRC_DEFAULT}" \
    || die "failed to push ${SRC_DEFAULT} to ${dest}"
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
  check_dest
  if [[ "$MODE" == transfer && "$DEST_EXISTS" -eq 1 ]]; then
    die "destination $(dest_slug) already exists"
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
