#!/bin/bash

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: ./$(basename "$0") <owner/repo-name> <new-name> <description> <homepage>"
  exit 1
fi

GITHUB_API_URL="https://api.github.com"
GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"

GITHUB_OWNER=$(echo "$1" | cut -d'/' -f1)
GITHUB_REPO_NAME=$(echo "$1" | cut -d'/' -f2)
GITHUB_REPO_NEW_NAME="$2"
GITHUB_REPO_PRIVATE="${3:-true}"
GITHUB_REPO_DESCRIPTION="${4:-}"
GITHUB_REPO_HOMEPAGE="${5:-}"

function update_repository() {
  curl -L \
    -X PATCH \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$GITHUB_API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME" \
    -d "{
         \"name\": \"$GITHUB_REPO_NEW_NAME\",
         \"description\": \"$GITHUB_REPO_DESCRIPTION\",
         \"homepage\": \"$GITHUB_REPO_HOMEPAGE\",
         \"private\": \"$GITHUB_REPO_PRIVATE\"
       }"
}

update_repository
