#!/bin/bash

set -euo pipefail

# Get the currently authenticated user.
function gh_graphql_owner() {
  GITHUB_OWNER=$(
  gh api graphql -f query='
    query {
      viewer {
        login
      }
    }' | jq -r '.data.viewer.login'
  )
}

function gh_graphql_get_repository() {
  gh_graphql_owner
  gh api graphql -F owner="$GITHUB_OWNER" -F name="${1}" -f query='
  query GetRepository($name: String!, $owner: String!) {
    repository(owner: $owner, name: $name) {
        createdAt
        name
        nameWithOwner
        url
      }
  }'
}

graphql_get_repository "$@"
