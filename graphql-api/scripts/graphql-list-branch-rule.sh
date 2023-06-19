#!/bin/bash

set -euo pipefail

# Get the currently authenticated user.
function gh_graphql_get_owner() {
  GITHUB_OWNER=$(
  gh api graphql -f query='
    query {
      viewer {
        login
      }
    }' | jq -r '.data.viewer.login'
  )
}

# Get branch protection rules from repository.
function gh_graphq_get_branch_protection() {
  gh_graphql_owner
  gh api graphql -F owner="$GITHUB_OWNER" -F repository="${1}" \
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

gh_graphq_get_branch_protection "$@"
