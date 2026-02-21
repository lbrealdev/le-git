#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: ./$(basename "$0") <owner>/<repository-name>"
  exit 1
fi

GITHUB_OWNER=$(echo "$1" | cut -d'/' -f1)
GITHUB_REPO=$(echo "$1" | cut -d'/' -f2)

function gh_graphql_get_repository() {
  repo="$1"

  gh api graphql -F owner="$GITHUB_OWNER" -F name="$repo" -f query='
  query GetRepository($name: String!, $owner: String!) {
    repository(owner: $owner, name: $name) {
        createdAt
        name
        nameWithOwner
        url
      }
  }'
}

gh_graphql_get_repository "$GITHUB_REPO"
