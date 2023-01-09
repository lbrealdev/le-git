#!/bin/bash

set -euo pipefail

GITHUB_REPOSITORY="$1"

function github_graphql_get_repository() {
  gh api graphql -F owner='lbrealdev' -F name="$GITHUB_REPOSITORY" -f query='
  query($name: String!, $owner: String!) {
    repository(owner: $owner, name: $name) {
        createdAt
        name
        nameWithOwner
        url
      }
  }'
}

github_graphql_get_repository
