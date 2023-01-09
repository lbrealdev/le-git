#!/bin/bash

set -euo pipefail

function graphql_get_repository() {
  gh api graphql -F owner='lbrealdev' -F name="${1}" -f query='
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
