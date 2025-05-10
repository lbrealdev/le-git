#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: $0 <login>"
    exit 1
}

if [ "$#" -lt 1 ]; then
  usage
fi

GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"
GITHUB_API_URL="https://api.github.com/graphql"
GRAPHQL_SCHEMA="{ \"query\": \"{ user(login: \\\"$1\\\") { id } }\" }"

# Get Legacy Global ID for authenticated user.
function gh_graphql_get_id() {

  curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    "$GITHUB_API_URL" -d "$GRAPHQL_SCHEMA" | \
    jq -r '. | "Legacy Global ID: \(.data.user.id)"'
}

# Get Next Global ID for authenticated user.
function gh_graphql_get_next_id() {

  # To get Next-Global-ID
  # Use this Header:
  # "X-Github-Next-Global-ID: 1"
  # https://docs.github.com/en/graphql/guides/migrating-graphql-global-node-ids
  curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-Github-Next-Global-ID: 1" \
    "$GITHUB_API_URL" -d "$GRAPHQL_SCHEMA" | \
    jq -r '. | "Next Global ID: \(.data.user.id)"'
}

# Legacy global ID
gh_graphql_get_id

# Next global ID
gh_graphql_get_next_id
