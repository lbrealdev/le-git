#!/bin/bash
# Offline: transfer accept-path and user/repos owner confirmation.

set -euo pipefail

SCRIPT=''
testdir=''

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate-owner-guard-test.sh [options]

Offline tests for gh-repo-migrate.sh owner guards: an unresolved SOURCE
login on a personal transfer uses the accept path, and user/repos create
runs only when the owner is a User matching the TARGET login.

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

resolve_script() {
  local repo_root
  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  if [[ -z "$SCRIPT" ]]; then
    SCRIPT="${repo_root}/scripts/gh-repo-migrate.sh"
  fi
  [[ -f "$SCRIPT" ]] || die "script not found: ${SCRIPT}"
  if [[ "$SCRIPT" != /* ]]; then
    SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
  fi
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
    if [[ "${GH_REPO_MIGRATE_TEST_USER_FAIL:-0}" == 1 ]]; then
      body='{"message":"Bad credentials"}'
      code=401
    else
      body="${GH_REPO_MIGRATE_TEST_USER_JSON:-{\"login\":\"alice\"}}"
    fi
    ;;
  "GET https://api.github.com/repos/acme/widget")
    body='{"default_branch":"main","private":false,"permissions":{"admin":true}}'
    ;;
  "GET https://api.github.com/repos/new-co/widget")
    body='{"message":"Not Found"}'
    code=404
    ;;
  "GET https://api.github.com/users/new-co")
    body="${GH_REPO_MIGRATE_TEST_OWNER_JSON:-{\"login\":\"new-co\",\"type\":\"User\"}}"
    ;;
  "POST https://api.github.com/repos/acme/widget/transfer")
    body='{"id":1}'
    code=201
    ;;
  "POST https://api.github.com/user/repos")
    if [[ "${GH_REPO_MIGRATE_TEST_ALLOW_USER_REPOS:-0}" == 1 ]]; then
      body='{"name":"widget"}'
      code=201
    else
      body='{"message":"user/repos should not be used"}'
      code=500
    fi
    ;;
  "POST https://api.github.com/orgs/new-co/repos")
    body='{"name":"widget"}'
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

write_passthrough_git() {
  local dest="$1" real_git="$2"
  cat >"$dest" <<EOF
#!/bin/bash
set -euo pipefail
exec "$(printf '%s' "$real_git")" "\$@"
EOF
  chmod +x "$dest"
}

setup_git_fixture() {
  local real_git="$1" github_root="$2"
  local work="${testdir}/fixture"
  mkdir -p "$work" "${github_root}/acme" "${github_root}/new-co"
  "$real_git" -C "$work" init -b main
  printf '%s\n' 'hello' >"${work}/README"
  "$real_git" -C "$work" add README
  "$real_git" -C "$work" commit -m initial
  "$real_git" clone --bare "$work" "${github_root}/acme/widget.git"
  "$real_git" init --bare "${github_root}/new-co/widget.git"
}

run_migrate() {
  local bin="$1" stdoutf="$2" stderrf="$3"
  shift 3
  env \
    -u GH_TOKEN \
    -u GITHUB_TOKEN \
    PATH="${bin}:${PATH}" \
    SOURCE_TOKEN=test-source-token \
    TARGET_TOKEN=test-target-token \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL="${testdir}/gitconfig" \
    HOME="${testdir}/home" \
    XDG_CONFIG_HOME="${testdir}/xdg" \
    GH_CONFIG_DIR="${testdir}/gh" \
    GH_REPO_MIGRATE_POLL_MAX=1 \
    "$SCRIPT" "$@" >"$stdoutf" 2>"$stderrf"
}

dump_run() {
  printf '%s\n' "--- stdout ---" >&2
  cat "$1" >&2 || true
  printf '%s\n' "--- stderr ---" >&2
  cat "$2" >&2 || true
}

main() {
  parse_args "$@"
  command -v git >/dev/null 2>&1 || die "git is required but not installed."
  resolve_script

  local real_git github_root bin
  real_git="$(command -v git)"
  real_git="$(cd "$(dirname "$real_git")" && pwd)/$(basename "$real_git")"

  testdir="$(mktemp -d "${TMPDIR:-/tmp}/gh-repo-migrate-test.XXXXXX")"
  trap 'rm -rf "$testdir"' EXIT
  github_root="${testdir}/github"
  bin="${testdir}/bin"
  mkdir -p "$github_root" "$bin" "${testdir}/home"

  {
    printf '[user]\n'
    printf '\tname = gh-repo-migrate-test\n'
    printf '\temail = gh-repo-migrate-test@localhost\n'
    printf '[init]\n'
    printf '\tdefaultBranch = main\n'
    printf '[protocol "file"]\n'
    printf '\tallow = always\n'
    printf '[url "%s/"]\n' "$github_root"
    printf '\tinsteadOf = https://github.com/\n'
  } >"${testdir}/gitconfig"

  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="${testdir}/gitconfig"
  export HOME="${testdir}/home"

  setup_git_fixture "$real_git" "$github_root"
  write_passthrough_git "${bin}/git" "$real_git"
  write_curl_shim "${bin}/curl"

  local stdoutf stderrf rc
  stdoutf="${testdir}/stdout"
  stderrf="${testdir}/stderr"

  # (a) Personal target whose login differs from SOURCE: accept path, do not poll.
  export GH_REPO_MIGRATE_TEST_USER_FAIL=0
  export GH_REPO_MIGRATE_TEST_USER_JSON='{"login":"alice"}'
  export GH_REPO_MIGRATE_TEST_OWNER_JSON='{"login":"new-co","type":"User"}'
  unset GH_REPO_MIGRATE_TEST_ALLOW_USER_REPOS || true
  set +e
  run_migrate "$bin" "$stdoutf" "$stderrf" acme/widget new-co -y
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "transfer with unresolved SOURCE login exited ${rc}"
    dump_run "$stdoutf" "$stderrf"
    exit 1
  fi
  if ! grep -Fq 'Transfer requested. new-co must accept it before it completes.' "$stdoutf"; then
    die "missing must-accept closing line"
  fi
  if grep -Fq 'did not become reachable' "$stderrf"; then
    die "unresolved SOURCE login timed out waiting for the target"
  fi

  # (b) User owner, TARGET login does not match: refuse user/repos.
  export GH_REPO_MIGRATE_TEST_USER_FAIL=0
  export GH_REPO_MIGRATE_TEST_USER_JSON='{"login":"alice"}'
  export GH_REPO_MIGRATE_TEST_OWNER_JSON='{"login":"new-co","type":"User"}'
  export GH_REPO_MIGRATE_TEST_APILOG="${testdir}/api.log"
  : >"${testdir}/api.log"
  set +e
  run_migrate "$bin" "$stdoutf" "$stderrf" acme/widget new-co --single-commit -y
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    die "expected create to fail when TARGET login does not match the owner"
  fi
  if ! grep -Fq 'cannot create new-co/widget because the TARGET credentials could not be confirmed for new-co.' "$stderrf"; then
    err "missing unconfirmed-TARGET error"
    dump_run "$stdoutf" "$stderrf"
    exit 1
  fi
  if grep -Fq 'POST https://api.github.com/user/repos' "${testdir}/api.log"; then
    die "user/repos was called for an unconfirmed personal owner"
  fi

  # Org targets still create under orgs/<owner>/repos.
  export GH_REPO_MIGRATE_TEST_OWNER_JSON='{"login":"new-co","type":"Organization"}'
  : >"${testdir}/api.log"
  set +e
  run_migrate "$bin" "$stdoutf" "$stderrf" acme/widget new-co --single-commit -y
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "org create exited ${rc}"
    dump_run "$stdoutf" "$stderrf"
    exit 1
  fi
  if ! grep -Fq 'POST https://api.github.com/orgs/new-co/repos' "${testdir}/api.log"; then
    die "org create did not POST orgs/new-co/repos"
  fi
  if grep -Fq 'POST https://api.github.com/user/repos' "${testdir}/api.log"; then
    die "org create used user/repos"
  fi

  printf '%s\n' "ok: owner guard (transfer accept path and user/repos confirm)"
}

main "$@"
