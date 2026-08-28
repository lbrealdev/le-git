#!/bin/bash

set -euo pipefail

print_help() {
  cat <<EOF
Usage: $(basename "$0") <login>

Print the GitHub GraphQL legacy and next-global IDs for a user login.

Options:
  -h, --help    Show this help and exit
EOF
}

case "${1:-}" in
  -h|--help)
    print_help
    exit 0
    ;;
esac

if [ "$#" -lt 1 ]; then
  print_help >&2
  exit 1
fi

if [[ -z "${GITHUB_AUTH_TOKEN:-}" ]]; then
  printf 'ERROR: GITHUB_AUTH_TOKEN is not set\n' >&2
  exit 2
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
