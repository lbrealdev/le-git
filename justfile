mod gql 'github/api/graphql-api/graphql.just'
mod rest 'github/api/rest-api/rest.just'
mod git 'git/git.just'

@setup:
    pre-commit install

# bash -n all *.sh; shellcheck git/scripts and scripts/ when available
check:
    #!/usr/bin/env bash
    set -euo pipefail
    mapfile -t files < <(find . -type f -name '*.sh' -not -path './.git/*' | sort)
    for f in "${files[@]}"; do
      bash -n "$f"
      printf 'bash -n OK %s\n' "$f"
    done
    if shellcheck --version >/dev/null 2>&1; then
      mapfile -t check_scripts < <(
        find git/scripts scripts -type f -name '*.sh' 2>/dev/null | sort
      )
      if ((${#check_scripts[@]} > 0)); then
        shellcheck -x --severity=warning "${check_scripts[@]}"
      fi
    else
      printf 'shellcheck not on PATH; skipped git/scripts and scripts/\n' >&2
    fi
