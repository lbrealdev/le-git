#!/bin/bash

set -euo pipefail

GITHUB_REPOSITORY="$1"

function graphql_get_repository() {
  gh api graphql -F owner='lbrealdev' -F name="$GITHUB_REPOSITORY" -f query='
  query GetRepository($name: String!, $owner: String!) {
    repository(owner: $owner, name: $name) {
        createdAt
        name
        nameWithOwner
        url
      }
  }'
}

graphql_get_repository
