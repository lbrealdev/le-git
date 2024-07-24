#!/bin/bash

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: ./$(basename -- "$0") <org-login>"
  exit 1
fi

GITHUB_ORG="$1"

if [ -z "${GITHUB_AUTH_TOKEN:-}" ]; then
  echo "Error: GITHUB_AUTH_TOKEN environment variable is not set." >&2
  exit 1
fi

GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"

page_cursor="null"
has_next_page=true

while $has_next_page; do
  if [ "$page_cursor" == "null" ]; then
    cursor_query="null"
  else
    cursor_query="\"$page_cursor\""
  fi

  graphql_schema=$(echo "query {
    organization(login: \"$GITHUB_ORG\") {
        id
        name
        login
        repositories(first: 100, after: $cursor_query) {
            nodes {
                id
                name
            }
            pageInfo {
                endCursor
                hasNextPage
            }
        }
    }
  }" | tr -d '\n' | tr -s ' ' | sed 's/"/\\"/g')

  query=$(curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/graphql \
    -d "{ \"query\": \"$graphql_schema\"}")

  repos=$(echo "$query" | jq -r .data.organization.repositories.nodes[].name)
  echo "$repos"

  page_cursor=$(echo "$query" | jq -r .data.organization.repositories.pageInfo.endCursor)
  has_next_page=$(echo "$query" | jq -r .data.organization.repositories.pageInfo.hasNextPage)

  if [ "$has_next_page" == "false" ]; then
    break
  fi

done
