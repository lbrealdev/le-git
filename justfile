mod gql 'github/api/graphql-api/graphql.just'
mod rest 'github/api/rest-api/rest.just'
mod git 'git/git.just'

@setup:
    pre-commit install

# bash -n all *.sh; shellcheck git/scripts when available
check:
    #!/usr/bin/env bash
    set -euo pipefail
    mapfile -t files < <(find . -type f -name '*.sh' -not -path './.git/*' | sort)
    for f in "${files[@]}"; do
      bash -n "$f"
      printf 'bash -n OK %s\n' "$f"
    done
    if shellcheck --version >/dev/null 2>&1; then
      mapfile -t git_scripts < <(find git/scripts -type f -name '*.sh' | sort)
      if ((${#git_scripts[@]} > 0)); then
        shellcheck -x --severity=warning "${git_scripts[@]}"
      fi
    else
      printf 'shellcheck not on PATH; skipped git/scripts\n' >&2
    fi
