#!/bin/bash
# Offline: --single-commit uses a neutral identity unless --host-identity.

set -euo pipefail

SCRIPT=''
testdir=''

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate-identity-test.sh [options]

Offline tests for gh-repo-migrate.sh --single-commit identity: the default
author/committer is gh-repo-migrate, forced through GIT_* env vars, with
UTC dates. --host-identity uses the host git identity instead.

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
    body='{"login":"new-co"}'
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
  https://api.github.com/user/repos)
    body='{"name":"widget"}'
    code=201
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

setup_repos() {
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
  local stdoutf="$1" stderrf="$2"
  shift 2
  env \
    -u GH_TOKEN \
    -u GITHUB_TOKEN \
    PATH="${testdir}/bin:${PATH}" \
    TMPDIR="${testdir}/watch-tmp" \
    SOURCE_TOKEN=test-source-token \
    TARGET_TOKEN=test-target-token \
    GIT_AUTHOR_NAME=attacker \
    GIT_AUTHOR_EMAIL=attacker@example.com \
    GIT_COMMITTER_NAME=attacker \
    GIT_COMMITTER_EMAIL=attacker@example.com \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL="${testdir}/gitconfig" \
    HOME="${testdir}/home" \
    "$SCRIPT" "$@" >"$stdoutf" 2>"$stderrf"
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

  if ! grep -Fq 'gh-repo-migrate@users.noreply.github.com' "$SCRIPT"; then
    die "script does not use the neutral noreply identity"
  fi
  if ! grep -Fq -- '--host-identity' "$SCRIPT"; then
    die "script is missing --host-identity"
  fi
  if ! grep -Fq -- '--host-identity' "${repo_root}/scripts/README.md"; then
    die "scripts/README.md does not document --host-identity"
  fi

  local real_git github_root
  real_git="$(command -v git)"
  real_git="$(cd "$(dirname "$real_git")" && pwd)/$(basename "$real_git")"

  testdir="$(mktemp -d "${TMPDIR:-/tmp}/gh-repo-migrate-test.XXXXXX")"
  trap 'rm -rf "$testdir"' EXIT
  github_root="${testdir}/github"
  mkdir -p "$github_root" "${testdir}/bin" "${testdir}/home" "${testdir}/watch-tmp"

  {
    printf '[user]\n'
    printf '\tname = host-user\n'
    printf '\temail = host-user@example.com\n'
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

  setup_repos "$real_git" "$github_root"
  write_curl_shim "${testdir}/bin/curl"

  local stdoutf stderrf rc an ae cn ce ad cd
  stdoutf="${testdir}/stdout"
  stderrf="${testdir}/stderr"

  set +e
  run_migrate "$stdoutf" "$stderrf" acme/widget new-co --single-commit -y
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "default identity run exited ${rc}"
    cat "$stdoutf" >&2 || true
    cat "$stderrf" >&2 || true
    exit 1
  fi
  grep -Fq 'gh-repo-migrate <gh-repo-migrate@users.noreply.github.com>' "$stdoutf" \
    || die "plan does not show the neutral identity"

  an="$("$real_git" -C "${github_root}/new-co/widget.git" log -1 --format='%an')"
  ae="$("$real_git" -C "${github_root}/new-co/widget.git" log -1 --format='%ae')"
  cn="$("$real_git" -C "${github_root}/new-co/widget.git" log -1 --format='%cn')"
  ce="$("$real_git" -C "${github_root}/new-co/widget.git" log -1 --format='%ce')"
  ad="$("$real_git" -C "${github_root}/new-co/widget.git" log -1 --format='%aI')"
  cd="$("$real_git" -C "${github_root}/new-co/widget.git" log -1 --format='%cI')"
  [[ "$an" == gh-repo-migrate ]] || die "author name is ${an}"
  [[ "$ae" == gh-repo-migrate@users.noreply.github.com ]] || die "author email is ${ae}"
  [[ "$cn" == gh-repo-migrate ]] || die "committer name is ${cn}"
  [[ "$ce" == gh-repo-migrate@users.noreply.github.com ]] || die "committer email is ${ce}"
  [[ "$ad" == *+00:00 ]] || die "author date is not UTC (${ad})"
  [[ "$cd" == *+00:00 ]] || die "committer date is not UTC (${cd})"

  "$real_git" -C "${github_root}/new-co/widget.git" update-ref -d HEAD
  "$real_git" -C "${github_root}/new-co/widget.git" update-ref -d refs/heads/main || true

  set +e
  run_migrate "$stdoutf" "$stderrf" acme/widget new-co --single-commit --host-identity -y
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "--host-identity run exited ${rc}"
    cat "$stdoutf" >&2 || true
    cat "$stderrf" >&2 || true
    exit 1
  fi
  grep -Fq 'host-user <host-user@example.com>' "$stdoutf" \
    || die "plan does not show the host identity"
  an="$("$real_git" -C "${github_root}/new-co/widget.git" log -1 --format='%an')"
  ae="$("$real_git" -C "${github_root}/new-co/widget.git" log -1 --format='%ae')"
  [[ "$an" == host-user ]] || die "--host-identity author name is ${an}"
  [[ "$ae" == host-user@example.com ]] || die "--host-identity author email is ${ae}"

  set +e
  run_migrate "$stdoutf" "$stderrf" acme/widget new-co --host-identity -n
  rc=$?
  set -e
  [[ "$rc" -eq 2 ]] || die "--host-identity without --single-commit exited ${rc}"

  printf '%s\n' "ok: single-commit identity is neutral unless --host-identity"
}

main "$@"
