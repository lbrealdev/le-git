#!/bin/bash
# Offline: only HTTP 404 means the migrate target is free.

set -euo pipefail

SCRIPT=''
testdir=''

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate-check-target-test.sh [options]

Offline tests for gh-repo-migrate.sh check_target: the target is free only
on an explicit HTTP 404. 401, 403, 5xx, and network errors stop the run.

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
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    url[[:space:]]=*)
      url="${line#*=}"
      url="${url# }"
      url="${url#\"}"
      url="${url%\"}"
      ;;
  esac
done

body=''
code=200
case "$url" in
  https://api.github.com/user)
    body='{"login":"alice"}'
    ;;
  https://api.github.com/repos/acme/widget)
    body='{"default_branch":"main","private":false,"permissions":{"admin":true}}'
    ;;
  https://api.github.com/repos/new-co/widget)
    case "${GH_REPO_MIGRATE_TEST_TARGET_CODE:-404}" in
      fail)
        printf 'curl: request failed\n' >&2
        exit 1
        ;;
      404)
        body='{"message":"Not Found"}'
        code=404
        ;;
      401)
        body='{"message":"Bad credentials"}'
        code=401
        ;;
      403)
        body='{"message":"Resource not accessible by integration"}'
        code=403
        ;;
      500)
        body='{"message":"Internal Server Error"}'
        code=500
        ;;
      *)
        printf 'error: bad TARGET_CODE\n' >&2
        exit 1
        ;;
    esac
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

run_dry() {
  local stdoutf="$1" stderrf="$2"
  env \
    -u GH_TOKEN \
    -u GITHUB_TOKEN \
    PATH="${testdir}/bin:${PATH}" \
    SOURCE_TOKEN=test-source-token \
    TARGET_TOKEN=test-target-token \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL="${testdir}/gitconfig" \
    HOME="${testdir}/home" \
    "$SCRIPT" acme/widget new-co --single-commit -n \
    >"$stdoutf" 2>"$stderrf"
}

expect_error() {
  local code="$1" stdoutf="$2" stderrf="$3" rc="$4"
  if [[ "$rc" -eq 0 ]]; then
    die "target HTTP ${code} was treated as success"
  fi
  if grep -Fq 'target new-co/widget is free' "$stdoutf"; then
    die "target HTTP ${code} was treated as free"
  fi
  if [[ ! -s "$stderrf" ]]; then
    die "target HTTP ${code} produced no error line"
  fi
}

main() {
  parse_args "$@"
  command -v git >/dev/null 2>&1 || die "git is required but not installed."

  local repo_root
  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  if [[ -z "$SCRIPT" ]]; then
    SCRIPT="${repo_root}/scripts/gh-repo-migrate.sh"
  fi
  [[ -f "$SCRIPT" ]] || die "script not found: ${SCRIPT}"
  if [[ "$SCRIPT" != /* ]]; then
    SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
  fi

  testdir="$(mktemp -d "${TMPDIR:-/tmp}/gh-repo-migrate-test.XXXXXX")"
  trap 'rm -rf "$testdir"' EXIT
  mkdir -p "${testdir}/bin" "${testdir}/home"
  : >"${testdir}/gitconfig"
  write_curl_shim "${testdir}/bin/curl"

  local stdoutf stderrf rc
  stdoutf="${testdir}/stdout"
  stderrf="${testdir}/stderr"

  export GH_REPO_MIGRATE_TEST_TARGET_CODE=404
  set +e
  run_dry "$stdoutf" "$stderrf"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "HTTP 404 dry-run exited ${rc}"
    cat "$stdoutf" >&2 || true
    cat "$stderrf" >&2 || true
    exit 1
  fi
  if ! grep -Fq 'target new-co/widget is free' "$stdoutf"; then
    die "HTTP 404 did not mark the target free"
  fi

  for code in 401 403 500 fail; do
    export GH_REPO_MIGRATE_TEST_TARGET_CODE="$code"
    set +e
    run_dry "$stdoutf" "$stderrf"
    rc=$?
    set -e
    expect_error "$code" "$stdoutf" "$stderrf" "$rc"
  done

  printf '%s\n' "ok: check_target treats only HTTP 404 as free"
}

main "$@"
