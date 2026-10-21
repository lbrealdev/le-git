#!/usr/bin/env bash
# Write: move a GitHub repository (transfer, mirror, or single commit).

set -euo pipefail

MODE=transfer
DRY_RUN=0
YES=0
QUIET=0
VERBOSE=0
TARGET_VISIBILITY=''
NO_TAGS=0
SOURCE=''
TARGET_OWNER=''
TARGET_NAME=''
AUTH_USER=''
SOURCE_VISIBILITY=''
SOURCE_DEFAULT_BRANCH=''
TARGET_EXISTS=0
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
target_slug() { printf '%s/%s' "$TARGET_OWNER" "$TARGET_NAME"; }

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate.sh <owner/repo> [<target-owner>[/<name>]] [options]

Move a GitHub repository to another owner (transfer, mirror, or single commit).
Auth: GH_TOKEN or GITHUB_TOKEN, else gh auth login.

Modes:
  (default)           Native transfer (requires admin on the source)
  --mirror            Clone --mirror and push to a new target repo
  --single-commit     Copy the default branch as one fresh commit

Options:
  --branch <name>     With --mirror: push only these branches (repeatable)
  --no-tags           With --mirror: do not push tags
  --public            Target visibility (mirror / single-commit)
  --private           Target visibility (mirror / single-commit)
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
      --public) TARGET_VISIBILITY=public; shift ;;
      --private) TARGET_VISIBILITY=private; shift ;;
      -*) usage_die "Unknown option: $1." ;;
      *) positional+=("$1"); shift ;;
    esac
  done
  ((${#positional[@]} >= 1)) || usage_die "Missing <owner/repo>."
  ((${#positional[@]} <= 2)) || usage_die "Unexpected argument: ${positional[2]}."
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
  if [[ -z "$TARGET_OWNER" ]]; then
    [[ -n "$AUTH_USER" ]] || die "could not resolve authenticated user"
    TARGET_OWNER="$AUTH_USER"
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
  [[ "$reply" == y || "$reply" == yes ]] || die "aborted"
}

source_meta() {
  local private
  private="$(gh api "repos/${SOURCE}" --jq .private)" || die "cannot read source ${SOURCE}"
  if [[ "$private" == true ]]; then SOURCE_VISIBILITY=private; else SOURCE_VISIBILITY=public; fi
  SOURCE_DEFAULT_BRANCH="$(gh api "repos/${SOURCE}" --jq .default_branch)" \
    || die "cannot read default branch of ${SOURCE}"
  TARGET_VISIBILITY="${TARGET_VISIBILITY:-$SOURCE_VISIBILITY}"
  ok "source ${SOURCE} (${SOURCE_VISIBILITY})"
}

# TARGET_EXISTS=0 free, 1 empty (resume). Dies on non-empty or auth errors.
check_target() {
  local target size refs errf
  target="$(target_slug)"
  errf="$(mktemp)"
  if gh api "repos/${target}" >"$errf" 2>&1; then
    size="$(gh api "repos/${target}" --jq .size)" || true
    refs="$(git_gh ls-remote "https://github.com/${target}.git" 2>/dev/null || true)"
    rm -f "$errf"
    if [[ "${size:-1}" == 0 && -z "$refs" ]]; then
      TARGET_EXISTS=1
      ok "target ${target} exists and is empty (will resume)"
      return 0
    fi
    die "target ${target} already exists and is not empty"
  fi
  if grep -qiE 'HTTP 403|HTTP 401|Bad credentials|rate limit' "$errf"; then
    cat "$errf" >&2
    rm -f "$errf"
    die "cannot check target ${target}"
  fi
  rm -f "$errf"
  TARGET_EXISTS=0
  ok "target ${target} is free"
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
  local target i="$1" vis_flag
  target="$(target_slug)"
  [[ "$TARGET_VISIBILITY" == public ]] && vis_flag=--public || vis_flag=--private
  if [[ "$TARGET_EXISTS" -eq 1 ]]; then
    out "  ${i}. Reuse empty ${target}"
  else
    out "  ${i}. Create ${target} (${TARGET_VISIBILITY})"
    step_cmd "gh repo create ${target} ${vis_flag}"
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
      out "  ${i}. commit-tree HEAD^{tree} on ${SOURCE_DEFAULT_BRANCH}"; i=$((i + 1))
      plan_create_or_reuse "$i"; i=$((i + 1))
      out "  ${i}. Push ${SOURCE_DEFAULT_BRANCH}"
      out "Note: history, issues, PRs, releases, wiki, and settings do not move."
      ;;
  esac
}

ensure_target_repo() {
  local target vis_flag
  target="$(target_slug)"
  if [[ "$TARGET_EXISTS" -eq 1 ]]; then
    out "Resuming into empty ${target}."
    return 0
  fi
  [[ "$TARGET_VISIBILITY" == public ]] && vis_flag=--public || vis_flag=--private
  gh repo create "$target" "$vis_flag" >/dev/null || die "failed to create ${target}"
}

do_transfer() {
  local target args=() errf owner_type waited=0
  target="$(target_slug)"
  owner_type="$(gh api "users/${TARGET_OWNER}" --jq .type)" \
    || die "cannot resolve owner type for ${TARGET_OWNER}"

  args=(-X POST "repos/${SOURCE}/transfer" -f "new_owner=${TARGET_OWNER}")
  [[ "$TARGET_NAME" != "${SOURCE#*/}" ]] && args+=(-f "new_name=${TARGET_NAME}")
  errf="$(mktemp)"
  if ! gh api "${args[@]}" >/dev/null 2>"$errf"; then
    if grep -qiE '422|Validation Failed' "$errf"; then
      cat "$errf" >&2
      rm -f "$errf"
      die "transfer failed: name clash or ${TARGET_OWNER} cannot receive it. Try --mirror or --single-commit."
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

  if [[ "$owner_type" == User && "$TARGET_OWNER" != "$AUTH_USER" ]]; then
    out "Transfer requested. ${TARGET_OWNER} must accept it before it completes."
    return 0
  fi

  local poll_max="${GH_REPO_MIGRATE_POLL_MAX:-60}"
  while ((waited < poll_max)); do
    if gh api "repos/${target}" >/dev/null 2>&1; then
      out "Transferred ${SOURCE} to ${target}."
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  warn "timed out waiting for ${target}"
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
  local mirror="$1" target="$2" b refspecs=() ref total=0
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
    git_gh -C "$mirror" push --mirror "https://github.com/${target}.git" \
      || die "failed to mirror-push to ${target}"
    out "  pushed: ${total}/${total} refs"
    return 0
  fi
  total=${#refspecs[@]}
  git_gh -C "$mirror" push "https://github.com/${target}.git" "${refspecs[@]}" \
    || die "failed to push selected refs to ${target}"
  out "  pushed: ${total}/${total} refs"
}

do_mirror() {
  local target mirror branches_n tags_n attrs
  target="$(target_slug)"
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
  ensure_target_repo
  mirror_push_refs "$mirror" "$target"
  out "Mirrored ${SOURCE} to ${target}."
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
  local target source_dir sha name email attrs
  target="$(target_slug)"
  TMPDIR_PATH="$(mktemp -d)"
  trap cleanup EXIT
  source_dir="${TMPDIR_PATH}/source"
  git_gh clone --depth 1 --branch "$SOURCE_DEFAULT_BRANCH" \
    "https://github.com/${SOURCE}.git" "$source_dir" \
    || die "failed to clone ${SOURCE}"
  if [[ -f "${source_dir}/.gitmodules" ]]; then
    warn ".gitmodules present; submodules are not initialized"
  fi
  attrs="$(cat "${source_dir}/.gitattributes" 2>/dev/null || true)"
  if [[ "$attrs" == *filter=lfs* ]]; then
    warn ".gitattributes uses filter=lfs; LFS objects are not copied"
  fi
  {
    read -r name
    read -r email
  } < <(commit_identity)
  sha="$(
    git -C "$source_dir" -c user.name="$name" -c user.email="$email" \
      commit-tree "HEAD^{tree}" -m "Initial commit"
  )" || die "failed to create commit-tree"
  ensure_target_repo
  git_gh -C "$source_dir" push "https://github.com/${target}.git" \
    "${sha}:refs/heads/${SOURCE_DEFAULT_BRANCH}" \
    || die "failed to push ${SOURCE_DEFAULT_BRANCH} to ${target}"
  out "Copied ${SOURCE} to ${target} as a single commit."
}

main() {
  parse_args "$@"
  ensure_tools_and_auth
  header
  ok "gh authenticated"
  source_meta
  if [[ "$(target_slug)" == "$SOURCE" ]]; then
    usage_die "source and target must differ."
  fi
  check_target
  if [[ "$MODE" == transfer && "$TARGET_EXISTS" -eq 1 ]]; then
    die "target $(target_slug) already exists"
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
