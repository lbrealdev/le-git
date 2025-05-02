#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: ./$(basename "$0") <login>"
  exit 1
fi

GITHUB_LOGIN="$1"
GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"

# Get Legacy Global ID for authenticated user.
function gh_graphql_get_id() {
  GRAPHQL="{ \"query\": \"{ user(login: \\\"$GITHUB_LOGIN\\\") { id } }\" }"
  
  curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/graphql \
    -d "$GRAPHQL" | \
    jq -r '. | "Legacy Global ID: \(.data.user.id)"'
}

# Get Next Global ID for authenticated user.
function gh_graphql_get_next_id() {
  GRAPHQL="{ \"query\": \"{ user(login: \\\"$GITHUB_LOGIN\\\") { id } }\" }"
  
  # To get Next-Global-ID
  # Use this Header:
  # "X-Github-Next-Global-ID: 1"
  # https://docs.github.com/en/graphql/guides/migrating-graphql-global-node-ids
  curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-Github-Next-Global-ID: 1" \
    https://api.github.com/graphql \
    -d "$GRAPHQL" | \
    jq -r '. | "Next Global ID: \(.data.user.id)"'
}

# Legacy global ID
gh_graphql_get_id

# Next global ID
gh_graphql_get_next_id
