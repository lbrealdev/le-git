#!/bin/bash
# Offline: mirror count lines use singular and plural nouns.

set -euo pipefail

SCRIPT=''
testdir=''

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate-plural-test.sh [options]

Offline test for gh-repo-migrate.sh count wording: 1 branch / 2 branches,
0 tags / 1 tag, and pushed N/N ref(s).

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

run_mirror() {
  local stdoutf="$1" stderrf="$2"
  env \
    -u GH_TOKEN \
    -u GITHUB_TOKEN \
    PATH="${testdir}/bin:${PATH}" \
    TMPDIR="${testdir}/tmp" \
    SOURCE_TOKEN=test-source-token \
    TARGET_TOKEN=test-target-token \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL="${testdir}/gitconfig" \
    HOME="${testdir}/home" \
    "$SCRIPT" acme/widget new-co --mirror -y \
    >"$stdoutf" 2>"$stderrf"
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

  local real_git github_root work source_bare target_bare
  real_git="$(command -v git)"
  real_git="$(cd "$(dirname "$real_git")" && pwd)/$(basename "$real_git")"

  testdir="$(mktemp -d "${TMPDIR:-/tmp}/gh-repo-migrate-test.XXXXXX")"
  trap 'rm -rf "$testdir"' EXIT
  github_root="${testdir}/github"
  work="${testdir}/fixture"
  source_bare="${github_root}/acme/widget.git"
  target_bare="${github_root}/new-co/widget.git"
  mkdir -p "${github_root}/acme" "${github_root}/new-co" "${testdir}/bin" \
    "${testdir}/home" "${testdir}/tmp" "$work"

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

  "$real_git" -C "$work" init -b main
  printf '%s\n' 'hello' >"${work}/README"
  "$real_git" -C "$work" add README
  "$real_git" -C "$work" commit -m initial
  "$real_git" clone --bare "$work" "$source_bare"
  "$real_git" init --bare "$target_bare"
  write_curl_shim "${testdir}/bin/curl"

  local stdoutf stderrf rc
  stdoutf="${testdir}/stdout"
  stderrf="${testdir}/stderr"

  set +e
  run_mirror "$stdoutf" "$stderrf"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "1-branch mirror exited ${rc}"
    cat "$stdoutf" >&2 || true
    cat "$stderrf" >&2 || true
    exit 1
  fi
  grep -Fq 'source: 1 branch, 0 tags' "$stdoutf" \
    || die "missing '1 branch, 0 tags'"
  grep -Fq 'pushed: 1/1 ref' "$stdoutf" \
    || die "missing '1/1 ref'"
  if grep -Fq '1 branches' "$stdoutf"; then
    die "still printed '1 branches'"
  fi
  if grep -Fq '1/1 refs' "$stdoutf"; then
    die "still printed '1/1 refs'"
  fi

  "$real_git" -C "$work" branch other
  "$real_git" -C "$work" tag v1
  rm -rf "$source_bare"
  "$real_git" clone --bare "$work" "$source_bare"

  set +e
  run_mirror "$stdoutf" "$stderrf"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    err "2-branch mirror exited ${rc}"
    cat "$stdoutf" >&2 || true
    cat "$stderrf" >&2 || true
    exit 1
  fi
  grep -Fq 'source: 2 branches, 1 tag' "$stdoutf" \
    || die "missing '2 branches, 1 tag'"
  grep -Fq 'pushed: 3/3 refs' "$stdoutf" \
    || die "missing '3/3 refs'"

  printf '%s\n' "ok: count lines use singular and plural forms"
}

main "$@"
