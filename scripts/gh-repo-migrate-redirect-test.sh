#!/bin/bash
# Offline: a redirected GET repos/<target> is not a taken target.

set -euo pipefail

SCRIPT=''
testdir=''

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate-redirect-test.sh [options]

Offline tests for gh-repo-migrate.sh repo_at: a 2xx GET that follows an
old-name redirect (full_name != requested slug) means the target slug is
free. The transfer wait loop only prints Transferred when the target
answers as itself.

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
method=GET
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    url[[:space:]]=*)
      url="${line#*=}"
      url="${url# }"
      url="${url#\"}"
      url="${url%\"}"
      ;;
    request[[:space:]]=*)
      method="${line#*=}"
      method="${method# }"
      method="${method#\"}"
      method="${method%\"}"
      ;;
  esac
done

log="${GH_REPO_MIGRATE_TEST_APILOG:-}"
if [[ -n "$log" ]]; then
  printf '%s %s\n' "$method" "$url" >>"$log"
fi

body=''
code=200
case "${method} ${url}" in
  "GET https://api.github.com/user")
    body='{"login":"alice"}'
    ;;
  "GET https://api.github.com/repos/acme/widget")
    body='{"full_name":"acme/widget","default_branch":"main","private":false,"permissions":{"admin":true},"size":10}'
    ;;
  "GET https://api.github.com/repos/alice/widget")
    case "${GH_REPO_MIGRATE_TEST_ALICE_MODE:-redirect}" in
      taken)
        body='{"full_name":"alice/widget","default_branch":"main","private":false,"size":12}'
        ;;
      *)
        body='{"full_name":"acme/widget","default_branch":"main","private":false,"size":12}'
        ;;
    esac
    ;;
  "GET https://api.github.com/repos/new-co/widget")
    count_file="${GH_REPO_MIGRATE_TEST_POLL_COUNT:-}"
    n=0
    if [[ -n "$count_file" ]]; then
      n="$(cat "$count_file" 2>/dev/null || true)"
      n="${n:-0}"
      n=$((n + 1))
      printf '%s\n' "$n" >"$count_file"
    fi
    if [[ "$n" -le 1 ]]; then
      body='{"message":"Not Found"}'
      code=404
    elif [[ "$n" -lt 4 ]]; then
      body='{"full_name":"acme/widget","default_branch":"main","private":false,"size":10}'
    else
      body='{"full_name":"new-co/widget","default_branch":"main","private":false,"size":10}'
    fi
    ;;
  "GET https://api.github.com/users/new-co")
    body='{"login":"new-co","type":"Organization"}'
    ;;
  "GET https://api.github.com/users/alice")
    body='{"login":"alice","type":"User"}'
    ;;
  "POST https://api.github.com/repos/acme/widget/transfer")
    body='{"id":1}'
    code=201
    ;;
  *)
    printf 'error: unexpected curl %s %s\n' "$method" "$url" >&2
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
    -u GH_TOKEN \
    -u GITHUB_TOKEN \
    PATH="${testdir}/bin:${PATH}" \
    SOURCE_TOKEN=test-source-token \
    TARGET_TOKEN=test-target-token \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL="${testdir}/gitconfig" \
    HOME="${testdir}/home" \
    GH_REPO_MIGRATE_POLL_MAX="${GH_REPO_MIGRATE_POLL_MAX:-5}" \
    "$@" >"$stdoutf" 2>"$stderrf"
}

dump_run() {
  printf '%s\n' "--- stdout ---" >&2
  cat "$1" >&2 || true
  printf '%s\n' "--- stderr ---" >&2
  cat "$2" >&2 || true
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

  testdir="$(mktemp -d "${TMPDIR:-/tmp}/gh-repo-migrate-test.XXXXXX")"
  trap 'rm -rf "$testdir"' EXIT
  mkdir -p "${testdir}/bin" "${testdir}/home"
  : >"${testdir}/gitconfig"
  write_curl_shim "${testdir}/bin/curl"

  local stdoutf stderrf rc
  stdoutf="${testdir}/stdout"
  stderrf="${testdir}/stderr"

  # Transfer dry run: target old name redirects to the source.
  export GH_REPO_MIGRATE_TEST_ALICE_MODE=redirect
  set +e
  run_cmd "$stdoutf" "$stderrf" \
    "$SCRIPT" acme/widget alice/widget -n
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "redirect dry-run exited ${rc}"
    dump_run "$stdoutf" "$stderrf"
    exit 1
  fi
  grep -Fq 'target alice/widget is free (old name, redirects to acme/widget)' "$stdoutf" \
    || die "missing redirect-is-free line"
  grep -Fq 'Dry run: nothing changed.' "$stdoutf" \
    || die "missing dry-run closing line"

  # Control: exact slug, non-empty.
  export GH_REPO_MIGRATE_TEST_ALICE_MODE=taken
  set +e
  run_cmd "$stdoutf" "$stderrf" \
    "$SCRIPT" acme/widget alice/widget -n
  rc=$?
  set -e
  [[ "$rc" -eq 1 ]] || die "taken target exited ${rc}, expected 1"
  grep -Fq 'alice/widget already exists and is not empty.' "$stderrf" \
    || die "missing already-exists error"

  # Wait loop: 404, then two redirects, then the target answers as itself.
  export GH_REPO_MIGRATE_TEST_APILOG="${testdir}/api.log"
  export GH_REPO_MIGRATE_TEST_POLL_COUNT="${testdir}/poll.count"
  : >"${testdir}/api.log"
  printf '%s\n' 0 >"${testdir}/poll.count"
  set +e
  run_cmd "$stdoutf" "$stderrf" \
    "$SCRIPT" acme/widget new-co -y
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "wait-loop transfer exited ${rc}"
    dump_run "$stdoutf" "$stderrf"
    exit 1
  fi
  grep -Fq 'Transferred acme/widget to new-co/widget.' "$stdoutf" \
    || die "missing Transferred closing line"
  local gets
  gets="$(grep -c 'GET https://api.github.com/repos/new-co/widget' "${testdir}/api.log" || true)"
  [[ "$gets" -ge 4 ]] || die "wait loop polled ${gets} times, expected 404 plus 3 self-checks"

  # Single-commit dry run to a redirected name.
  export GH_REPO_MIGRATE_TEST_ALICE_MODE=redirect
  unset GH_REPO_MIGRATE_TEST_APILOG || true
  set +e
  run_cmd "$stdoutf" "$stderrf" \
    "$SCRIPT" acme/widget alice/widget --single-commit -n
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "single-commit redirect dry-run exited ${rc}"
    dump_run "$stdoutf" "$stderrf"
    exit 1
  fi
  grep -Fq 'target alice/widget is free (old name, redirects to acme/widget)' "$stdoutf" \
    || die "single-commit missing redirect-is-free line"
  grep -Fq 'Dry run: nothing changed.' "$stdoutf" \
    || die "single-commit missing dry-run closing line"

  printf '%s\n' "ok: redirected target slugs are free; wait loop requires a real target"
}

main "$@"
