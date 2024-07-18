#!/bin/bash

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: ./$(basename -- "$0") <org-login>"
  exit 1
fi

GITHUB_ORG="$1"
GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"

graphql_schema='query {
    organization(login: "'"$GITHUB_ORG"'") {
        id
        name
        login
        repositories(first: 100, after: null) {
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
}'

# Formatted schema
graphql_schema_format=$(echo "$graphql_schema" | tr -d '\n' | tr -s ' ' | sed 's/"/\\"/g')

# Run graphql query
query=$(curl -sL \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/graphql \
  -d "{ \"query\": \"$graphql_schema_format\"}")

repos=$(echo "$query" | jq -r .)

# Print repositories from GitHub Org
echo "$repos"
