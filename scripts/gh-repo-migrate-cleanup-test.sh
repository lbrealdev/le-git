#!/bin/bash
# Offline: no -v, plain plan text, valid names, escaped JSON, TARGET_USER.

set -euo pipefail

SCRIPT=''
testdir=''

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate-cleanup-test.sh [options]

Offline tests for gh-repo-migrate.sh cleanup: -v is gone, plan wording is
plain text, owner/name arguments are validated, JSON bodies are escaped,
and AUTH_USER is named TARGET_USER.

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
bodyfile=''
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
    data-binary[[:space:]]=*)
      bodyfile="${line#*=}"
      bodyfile="${bodyfile# }"
      bodyfile="${bodyfile#\"}"
      bodyfile="${bodyfile%\"}"
      bodyfile="${bodyfile#@}"
      ;;
  esac
done

if [[ -n "${GH_REPO_MIGRATE_TEST_BODYLOG:-}" && -n "$bodyfile" && -f "$bodyfile" ]]; then
  cat "$bodyfile" >"$GH_REPO_MIGRATE_TEST_BODYLOG"
fi

body=''
code=200
case "${method} ${url}" in
  "GET https://api.github.com/user")
    body='{"login":"alice"}'
    ;;
  "GET https://api.github.com/repos/acme/widget")
    body='{"default_branch":"main","private":false,"permissions":{"admin":true}}'
    ;;
  "GET https://api.github.com/repos/new-co/widget")
    body='{"message":"Not Found"}'
    code=404
    ;;
  "GET https://api.github.com/users/new-co")
    body='{"login":"new-co","type":"User"}'
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
    GH_REPO_MIGRATE_TEST_BODYLOG="${testdir}/body.json" \
    "$SCRIPT" "$@" >"$stdoutf" 2>"$stderrf"
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

  if grep -qE 'AUTH_USER|step_cmd|^VERBOSE=|-v\|--verbose' "$SCRIPT"; then
    die "script still has AUTH_USER, step_cmd, VERBOSE, or --verbose"
  fi
  if ! grep -q 'TARGET_USER' "$SCRIPT"; then
    die "script does not use TARGET_USER"
  fi
  if ! grep -q 'json_str_encode' "$SCRIPT"; then
    die "script does not escape JSON request bodies"
  fi

  testdir="$(mktemp -d "${TMPDIR:-/tmp}/gh-repo-migrate-test.XXXXXX")"
  trap 'rm -rf "$testdir"' EXIT
  mkdir -p "${testdir}/bin" "${testdir}/home"
  : >"${testdir}/gitconfig"
  write_curl_shim "${testdir}/bin/curl"

  local stdoutf stderrf rc help
  stdoutf="${testdir}/stdout"
  stderrf="${testdir}/stderr"

  set +e
  run_cmd "$stdoutf" "$stderrf" --help
  rc=$?
  set -e
  help="$(cat "$stdoutf")"
  [[ "$rc" -eq 0 ]] || die "--help exited ${rc}"
  if printf '%s\n' "$help" | grep -qE -- '-v|verbose|step_cmd'; then
    die "--help still mentions verbose mode"
  fi

  set +e
  run_cmd "$stdoutf" "$stderrf" acme/widget new-co -v -n
  rc=$?
  set -e
  if [[ "$rc" -ne 2 ]]; then
    die "-v should be an unknown option (exit 2), got ${rc}"
  fi

  set +e
  run_cmd "$stdoutf" "$stderrf" 'bad owner/widget' new-co -n
  rc=$?
  set -e
  [[ "$rc" -eq 2 ]] || die "invalid SOURCE owner exited ${rc}"
  grep -Fq 'is not a valid owner name.' "$stderrf" \
    || die "invalid SOURCE owner missing validation error"

  set +e
  run_cmd "$stdoutf" "$stderrf" acme/widget 'bad owner' -n
  rc=$?
  set -e
  [[ "$rc" -eq 2 ]] || die "invalid TARGET owner exited ${rc}"
  grep -Fq 'is not a valid owner name.' "$stderrf" \
    || die "invalid TARGET owner missing validation error"

  set +e
  run_cmd "$stdoutf" "$stderrf" acme/widget new-co --single-commit -n
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || die "single-commit dry-run exited ${rc}"
  grep -Fq 'Rebuild main as one commit' "$stdoutf" \
    || die "plan is missing Rebuild main as one commit"
  if grep -Fq 'commit-tree' "$stdoutf"; then
    die "plan still mentions commit-tree"
  fi
  if grep -Fq 'Shallow-clone' "$stdoutf"; then
    die "plan still mentions Shallow-clone"
  fi
  grep -Fq 'authenticated (SOURCE: alice, TARGET: alice)' "$stdoutf" \
    || die "authenticated line does not use TARGET login"

  set +e
  run_cmd "$stdoutf" "$stderrf" acme/widget new-co -y
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || die "transfer exited ${rc}"
  [[ -f "${testdir}/body.json" ]] || die "transfer JSON body was not captured"
  if command -v jq >/dev/null 2>&1; then
    jq -e '.new_owner == "new-co"' "${testdir}/body.json" >/dev/null \
      || die "transfer JSON body is not valid or missing new_owner"
  else
    grep -Fq '"new_owner":"new-co"' "${testdir}/body.json" \
      || die "transfer JSON body missing escaped new_owner"
  fi

  printf '%s\n' "ok: cleanup (no -v, TARGET_USER, validated names, escaped JSON)"
}

main "$@"
