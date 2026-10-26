#!/bin/bash
# Offline regression: --single-commit clones the source without a work tree.

set -euo pipefail

SOURCE_SLUG=acme/widget
TARGET_OWNER=new-co
TARGET_SLUG=new-co/widget
DEFAULT_BRANCH=main
SCRIPT=''
testdir=''

print_help() {
  cat <<'EOF'
Usage: gh-repo-migrate-single-commit-test.sh [options]

Offline regression test for gh-repo-migrate.sh --single-commit: the source
is cloned as a bare repo (no working tree), so files such as mise.toml never
land on disk under the script temp dir.

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
      -h|--help)
        print_help
        exit 0
        ;;
      --script)
        [[ $# -ge 2 ]] || usage_die "--script needs a path."
        SCRIPT="$2"
        shift 2
        ;;
      -*)
        usage_die "Unknown option $1."
        ;;
      *)
        usage_die "Unexpected argument $1."
        ;;
    esac
  done
}

write_git_shim() {
  local dest="$1"
  cat >"$dest" <<'EOF'
#!/bin/bash
set -euo pipefail

real="${GH_REPO_MIGRATE_TEST_REAL_GIT:-}"
if [[ -z "$real" || ! -x "$real" ]]; then
  printf 'error: GH_REPO_MIGRATE_TEST_REAL_GIT is unset or not executable\n' >&2
  exit 1
fi

has_mise() {
  local dir="$1"
  [[ -n "$dir" ]] || return 1
  if [[ "$dir" != /* && -d "$dir" ]]; then
    dir="$(cd "$dir" && pwd)"
  fi
  while [[ -n "$dir" && "$dir" != / ]]; do
    if [[ -f "${dir}/mise.toml" ]]; then
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

effective="$(pwd)"
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
  case "${args[$i]}" in
    -C)
      i=$((i + 1))
      if [[ $i -lt ${#args[@]} ]]; then
        effective="${args[$i]}"
      fi
      ;;
    -c)
      i=$((i + 1))
      ;;
  esac
  i=$((i + 1))
done

if has_mise "$(pwd)" || has_mise "$effective"; then
  printf 'error: mise.toml found in git cwd or a parent; refusing to run\n' >&2
  exit 1
fi

set +e
"$real" "$@"
rc=$?
set -e

if [[ -n "${GH_REPO_MIGRATE_WATCH_TMP:-}" ]]; then
  found="$(find "$GH_REPO_MIGRATE_WATCH_TMP" -name mise.toml -type f -print -quit 2>/dev/null || true)"
  if [[ -n "$found" ]]; then
    printf 'error: mise.toml existed under the temp dir (%s)\n' "$found" >&2
    exit 1
  fi
fi

exit "$rc"
EOF
  chmod +x "$dest"
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
    body='{"name":"widget","full_name":"new-co/widget"}'
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

build_source_repo() {
  local work="$1" bare="$2" real_git="$3"
  mkdir -p "$work"
  "$real_git" -C "$work" init -b "$DEFAULT_BRANCH"
  printf '%s\n' '[tools]' 'node = "20"' >"${work}/mise.toml"
  cat >"${work}/.gitmodules" <<'EOF'
[submodule "vendor/foo"]
	path = vendor/foo
	url = https://github.com/example/foo.git
EOF
  printf '%s\n' '*.bin filter=lfs diff=lfs merge=lfs -text' >"${work}/.gitattributes"
  printf '%s\n' 'hello' >"${work}/README"
  "$real_git" -C "$work" add mise.toml .gitmodules .gitattributes README
  "$real_git" -C "$work" commit -m 'initial'
  mkdir -p "$(dirname "$bare")"
  "$real_git" clone --bare "$work" "$bare"
}

main() {
  parse_args "$@"

  if ! command -v git >/dev/null 2>&1; then
    die "git is required but not installed."
  fi
  if ! command -v find >/dev/null 2>&1; then
    die "find is required but not installed."
  fi

  local repo_root
  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  if [[ -z "$SCRIPT" ]]; then
    SCRIPT="${repo_root}/scripts/gh-repo-migrate.sh"
  fi
  [[ -f "$SCRIPT" ]] || die "script not found: ${SCRIPT}"
  if [[ "$SCRIPT" != /* ]]; then
    SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
  fi

  local real_git github_root watch_tmp bin fixture_work
  local source_bare target_bare workdir stdoutf stderrf
  real_git="$(command -v git)"
  real_git="$(cd "$(dirname "$real_git")" && pwd)/$(basename "$real_git")"

  testdir="$(mktemp -d "${TMPDIR:-/tmp}/gh-repo-migrate-test.XXXXXX")"
  trap 'rm -rf "$testdir"' EXIT

  github_root="${testdir}/github"
  watch_tmp="${testdir}/watch-tmp"
  bin="${testdir}/bin"
  fixture_work="${testdir}/fixture"
  source_bare="${github_root}/${SOURCE_SLUG}.git"
  target_bare="${github_root}/${TARGET_SLUG}.git"
  workdir="${testdir}/work"
  mkdir -p "$github_root" "$watch_tmp" "$bin" "$workdir" "${testdir}/home"

  {
    printf '[user]\n'
    printf '\tname = gh-repo-migrate-test\n'
    printf '\temail = gh-repo-migrate-test@localhost\n'
    printf '[init]\n'
    printf '\tdefaultBranch = %s\n' "$DEFAULT_BRANCH"
    printf '[protocol "file"]\n'
    printf '\tallow = always\n'
    printf '[url "%s/"]\n' "$github_root"
    printf '\tinsteadOf = https://github.com/\n'
  } >"${testdir}/gitconfig"

  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="${testdir}/gitconfig"
  export HOME="${testdir}/home"
  export XDG_CONFIG_HOME="${testdir}/xdg"
  export GH_CONFIG_DIR="${testdir}/gh"

  build_source_repo "$fixture_work" "$source_bare" "$real_git"
  "$real_git" init --bare "$target_bare"

  write_git_shim "${bin}/git"
  write_curl_shim "${bin}/curl"

  local source_tree
  source_tree="$("$real_git" -C "$source_bare" rev-parse "HEAD^{tree}")"

  stdoutf="${testdir}/stdout"
  stderrf="${testdir}/stderr"
  set +e
  env \
    -u GH_TOKEN \
    -u GITHUB_TOKEN \
    PATH="${bin}:${PATH}" \
    TMPDIR="$watch_tmp" \
    SOURCE_TOKEN=test-source-token \
    TARGET_TOKEN=test-target-token \
    GH_REPO_MIGRATE_TEST_REAL_GIT="$real_git" \
    GH_REPO_MIGRATE_WATCH_TMP="$watch_tmp" \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL="${testdir}/gitconfig" \
    HOME="${testdir}/home" \
    XDG_CONFIG_HOME="${testdir}/xdg" \
    GH_CONFIG_DIR="${testdir}/gh" \
    "$SCRIPT" "$SOURCE_SLUG" "$TARGET_OWNER" --single-commit -y \
    >"$stdoutf" 2>"$stderrf"
  local rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    err "migrate exited ${rc}"
    printf '%s\n' '--- stdout ---' >&2
    cat "$stdoutf" >&2 || true
    printf '%s\n' '--- stderr ---' >&2
    cat "$stderrf" >&2 || true
    exit 1
  fi

  if ! grep -Fq '.gitmodules present; submodules are not initialized' "$stdoutf"; then
    die "missing .gitmodules warning"
  fi
  if ! grep -Fq '.gitattributes uses filter=lfs; LFS objects are not copied' "$stdoutf"; then
    die "missing LFS warning"
  fi

  local count parent_rc target_tree
  count="$("$real_git" -C "$target_bare" rev-list --count HEAD)"
  [[ "$count" == 1 ]] || die "target has ${count} commits, expected 1"

  set +e
  "$real_git" -C "$target_bare" rev-parse --verify 'HEAD^' >/dev/null 2>&1
  parent_rc=$?
  set -e
  [[ "$parent_rc" -ne 0 ]] || die "target HEAD has a parent"

  target_tree="$("$real_git" -C "$target_bare" rev-parse 'HEAD^{tree}')"
  [[ "$target_tree" == "$source_tree" ]] || \
    die "target tree ${target_tree} != source tree ${source_tree}"

  local leftover
  leftover="$(find "$watch_tmp" -name mise.toml -type f -print -quit 2>/dev/null || true)"
  [[ -z "$leftover" ]] || die "mise.toml existed under the temp dir (${leftover})"

  printf '%s\n' "ok: --single-commit cloned a bare source and pushed one commit"
}

main "$@"
