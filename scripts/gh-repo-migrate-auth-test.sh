#!/bin/bash
# Offline: per-side vs shared auth, no mixed tokens.

set -euo pipefail

SCRIPT=''
testdir=''

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate-auth-test.sh [options]

Offline tests for gh-repo-migrate.sh auth: one mode per run (per-side or
shared), missing per-side tokens exit 2, a bad token exits 1, and GH_TOKEN
is ignored when SOURCE_TOKEN / TARGET_TOKEN are set.

Options:
  --script PATH   gh-repo-migrate.sh to run (default: this repo's copy)
  -h, --help      Show this help and exit
EOF
}

err() { printf 'error: %s\n' "$*" >&2; }
die() { err "$1"; exit 1; }
usage_die() { err "$1 Try --help."; exit 2; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) print_help; exit 0 ;;
      --script)
        [[ $# -ge 2 ]] || usage_die "--script needs a path."
        SCRIPT="$2"
        shift 2
        ;;
      -*) usage_die "Unknown option $1." ;;
      *) usage_die "Unexpected argument $1." ;;
    esac
  done
}

write_curl_shim() {
  local dest="$1"
  cat >"$dest" <<'EOF'
#!/bin/bash
set -euo pipefail

out=''
i=0
args=("$@")
while [[ $i -lt ${#args[@]} ]]; do
  case "${args[$i]}" in
    -o)
      i=$((i + 1))
      out="${args[$i]:-}"
      ;;
  esac
  i=$((i + 1))
done

url=''
token=''
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    url[[:space:]]=*)
      url="${line#*=}"
      url="${url# }"
      url="${url#\"}"
      url="${url%\"}"
      ;;
    header[[:space:]]=\ \"Authorization:*)
      token="${line##*Bearer }"
      token="${token%\"}"
      ;;
  esac
done

body=''
code=200
case "$url" in
  https://api.github.com/user)
    if [[ "${GH_REPO_MIGRATE_TEST_BAD_TOKEN:-0}" == 1 ]]; then
      body='{"message":"Bad credentials"}'
      code=401
    elif [[ "$token" == test-source-token || "$token" == test-target-token || "$token" == test-shared-token ]]; then
      body='{"login":"alice"}'
    else
      body='{"message":"Bad credentials"}'
      code=401
    fi
    ;;
  https://api.github.com/repos/acme/widget)
    body='{"default_branch":"main","private":false,"permissions":{"admin":true}}'
    ;;
  https://api.github.com/repos/new-co/widget)
    body='{"message":"Not Found"}'
    code=404
    ;;
  https://api.github.com/users/new-co)
    body='{"login":"new-co","type":"User"}'
    ;;
  *)
    printf 'error: unexpected curl url %s\n' "$url" >&2
    exit 1
    ;;
esac

if [[ -n "$out" ]]; then
  printf '%s\n' "$body" >"$out"
fi
printf '%s' "$code"
EOF
  chmod +x "$dest"
}

run_cmd() {
  local stdoutf="$1" stderrf="$2"
  shift 2
  env \
    PATH="${testdir}/bin:${PATH}" \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL="${testdir}/gitconfig" \
    HOME="${testdir}/home" \
    "$@" >"$stdoutf" 2>"$stderrf"
}

main() {
  parse_args "$@"

  local repo_root
  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  if [[ -z "$SCRIPT" ]]; then
    SCRIPT="${repo_root}/scripts/gh-repo-migrate.sh"
  fi
  [[ -f "$SCRIPT" ]] || die "script not found: ${SCRIPT}"
  if [[ "$SCRIPT" != /* ]]; then
    SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
  fi

  if grep -q 'resolve_side_token' "$SCRIPT"; then
    die "script still has resolve_side_token"
  fi
  if ! grep -q 'resolve_auth' "$SCRIPT"; then
    die "script does not have resolve_auth"
  fi

  testdir="$(mktemp -d "${TMPDIR:-/tmp}/gh-repo-migrate-test.XXXXXX")"
  trap 'rm -rf "$testdir"' EXIT
  mkdir -p "${testdir}/bin" "${testdir}/home"
  : >"${testdir}/gitconfig"
  write_curl_shim "${testdir}/bin/curl"

  local stdoutf stderrf rc
  stdoutf="${testdir}/stdout"
  stderrf="${testdir}/stderr"

  # only SOURCE_TOKEN + mirror -> exit 2
  set +e
  run_cmd "$stdoutf" "$stderrf" \
    env -u GH_TOKEN -u GITHUB_TOKEN -u TARGET_TOKEN \
    SOURCE_TOKEN=test-source-token \
    "$SCRIPT" acme/widget new-co --mirror -n
  rc=$?
  set -e
  [[ "$rc" -eq 2 ]] || die "SOURCE_TOKEN-only mirror exited ${rc}, expected 2"
  grep -Fq 'TARGET_TOKEN is not set; per-side mode needs both. Set it, or unset SOURCE_TOKEN to use one shared token.' "$stderrf" \
    || die "missing TARGET_TOKEN per-side error"

  # only SOURCE_TOKEN + transfer dry-run -> runs
  set +e
  run_cmd "$stdoutf" "$stderrf" \
    env -u GH_TOKEN -u GITHUB_TOKEN -u TARGET_TOKEN \
    SOURCE_TOKEN=test-source-token \
    "$SCRIPT" acme/widget new-co -n
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "SOURCE_TOKEN-only transfer exited ${rc}"
    cat "$stdoutf" >&2 || true
    cat "$stderrf" >&2 || true
    exit 1
  fi
  grep -Fq 'Auth (per-side):' "$stdoutf" || die "transfer missing Auth (per-side)"
  grep -Fq 'source  alice  via SOURCE_TOKEN' "$stdoutf" \
    || die "transfer Auth missing SOURCE line"
  grep -Fq 'target  (not used: transfer runs as source)' "$stdoutf" \
    || die "transfer Auth missing unused TARGET line"

  # bad token -> exit 1
  export GH_REPO_MIGRATE_TEST_BAD_TOKEN=1
  set +e
  run_cmd "$stdoutf" "$stderrf" \
    env -u GH_TOKEN -u GITHUB_TOKEN \
    SOURCE_TOKEN=test-source-token \
    TARGET_TOKEN=test-target-token \
    "$SCRIPT" acme/widget new-co --single-commit -n
  rc=$?
  set -e
  unset GH_REPO_MIGRATE_TEST_BAD_TOKEN
  [[ "$rc" -eq 1 ]] || die "bad token exited ${rc}, expected 1"
  grep -Fq 'SOURCE token did not resolve to a login.' "$stderrf" \
    || die "bad token missing SOURCE login error"

  # per-side + GH_TOKEN -> warning
  set +e
  run_cmd "$stdoutf" "$stderrf" \
    env -u GITHUB_TOKEN \
    SOURCE_TOKEN=test-source-token \
    TARGET_TOKEN=test-target-token \
    GH_TOKEN=should-be-ignored \
    "$SCRIPT" acme/widget new-co --single-commit -n
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "per-side with GH_TOKEN exited ${rc}"
    cat "$stdoutf" >&2 || true
    cat "$stderrf" >&2 || true
    exit 1
  fi
  grep -Fq 'GH_TOKEN ignored' "$stdoutf" || die "missing GH_TOKEN ignored warning"
  grep -Fq 'Auth (per-side):' "$stdoutf" || die "per-side with GH_TOKEN missing Auth header"
  if grep -Fq 'via GH_TOKEN' "$stdoutf"; then
    die "per-side mode used GH_TOKEN"
  fi

  printf '%s\n' "ok: auth is per-side or shared, never mixed"
}

main "$@"
