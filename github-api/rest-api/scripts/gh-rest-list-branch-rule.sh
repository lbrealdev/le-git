#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: ./$(basename "$0") <owner>/<repository-name>"
  exit 1
fi

GITHUB_OWNER=$(echo "$1" | cut -d'/' -f1)
GITHUB_REPO=$(echo "$1" | cut -d'/' -f2)

# List branches and filter for branches
# with protected equal to 'true' and get branch protection.
function gh_api_get_branch_protection() {
  repo="$1"

  fetch=$(gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$GITHUB_OWNER/$repo/branches")

  branches=$(echo "$fetch" | jq -r '.[] | "\(.name)/\(.protected)"' | sort -r)
  
  readarray -t _branches <<< "$branches"
  
  found_branch_protection=false

  for b in "${_branches[@]}"; do
    if [[ "$b" =~ [a-z]+/true ]]; then
      found_branch_protection=true
      protected_branches="${BASH_REMATCH[0]}"
      protected_branch_names=$(echo "$protected_branches" | cut -d'/' -f1)

      gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/repos/$GITHUB_OWNER/$repo/branches/$protected_branch_names/protection"
    fi
  done

  if ! "$found_branch_protection"; then
    echo "Branch protection rules not found!"
  fi
}

gh_api_get_branch_protection "$GITHUB_REPO"
