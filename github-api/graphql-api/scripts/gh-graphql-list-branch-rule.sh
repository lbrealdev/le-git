#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: ./$(basename "$0") <owner>/<repository-name>"
  exit 1
fi

GITHUB_OWNER=$(echo "$1" | cut -d'/' -f1)
GITHUB_REPO=$(echo "$1" | cut -d'/' -f2)

# Get branch protection rules from repository.
function gh_graphq_get_branch_protection() {
  repo="$1"

  gh api graphql -F owner="$GITHUB_OWNER" -F repository="$repo" \
    -f query='
    query GetBranchProtectionRules($owner:String!, $repository:String!) {
      repository(owner: $owner, name: $repository) {
        branchProtectionRules(first: 10) {
          nodes {
            creator { login, url, resourcePath }
            pattern
            repository {
              createdAt
              description
              isInOrganization
              languages(first: 10) { nodes { name } }
              primaryLanguage { name }
              url
            }
          }
        }
      }
    }'
}

gh_graphq_get_branch_protection "$GITHUB_REPO"
