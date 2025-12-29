#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: ./$(basename "$0") <org-login>"
  exit 1
fi

GITHUB_LOGIN="$1"
GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"

function gh_graphql_get_org_id() {
  QUERY="{ \"query\": \"{ organization(login: \\\"$GITHUB_LOGIN\\\") { id, login } }\" }"

  GITHUB_ORG_LOGIN=$(curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/graphql \
    -d "$QUERY" | \
    jq -r '.data.organization.login')
}

function gh_graphql_fetch_repos() {

  gh api graphql -F owner="$GITHUB_ORG_LOGIN" \
    -f query='
    query GetReposFromOrg($owner: String!) {
      organization(login: $owner) {
        id
        name
        login
        description
        resourcePath
        createdAt
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

  #query='{"query {
  #    organazation(login: "O_kgDOB5GwyQ") {
  #      repositories(first: 100, after: null) {
  #        nodes {
  #          name
  #          url
  #        }
  #        pageInfo {
  #          endCursor
  #          hasNextPage
  #        }
  #      }
  #    }
  #  }"
  #}'
}

gh_graphql_get_org_id
gh_graphql_fetch_repos
