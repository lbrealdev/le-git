#!/bin/bash

# GitHub REST API
# https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#update-a-repository

set -euo pipefail

usage() {
    echo "Usage: $0 <repo-name> [--name <new-name>] [--description <description>] [--homepage <homepage>]"
    exit 1
}

# Function to display error for empty argument
error_empty_argument() {
    echo "Error: Argument for $1 cannot be empty."
    usage
}

log() {
  local msg="$1"
  local timestamp
  timestamp=$(date -u '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $msg"
}

# Check if there enough arguments
if [ "$#" -lt 1 ]; then
  usage
fi

GITHUB_API_URL="https://api.github.com"
GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"

# Initialize variables
GITHUB_REPO_OWNER=""
GITHUB_REPO_NAME=""
GITHUB_REPO_NEW_NAME=""
GITHUB_REPO_PRIVATE=""
GITHUB_REPO_DESCRIPTION=""
GITHUB_REPO_HOMEPAGE=""

# Parse repository name
# Supported repository name format
# repository for the authenticated user: repo-name
# repository from another login for the authenticated user: owner/repo-name
if [[ "$1" == */* ]]; then
    IFS='/' read -r GITHUB_REPO_OWNER GITHUB_REPO_NAME <<< "$1"
else
    GITHUB_REPO_NAME="$1"
fi

shift

if [[ -z "$GITHUB_REPO_NAME" ]]; then
  echo "Error: Repository name must be provided."
  usage
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --name)
        if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
          GITHUB_REPO_NEW_NAME="$2"
          shift 2
        else
          error_empty_argument "--name"
        fi
        ;;
    --description)
        if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
          GITHUB_REPO_DESCRIPTION="$2"
          shift 2
        else
          error_empty_argument "--description"
        fi
        ;;
    --private)
        if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
          GITHUB_REPO_PRIVATE="$2"
          shift 2
        else
          error_empty_argument "--private"
        fi
        ;;
    --homepage)
        if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
          GITHUB_REPO_HOMEPAGE="$2"
          shift 2
        else
          error_empty_argument "--homepage"
        fi
        ;;
    *) echo "Invalid argument: $1"; usage;;
  esac
done

if [ -z "$GITHUB_REPO_NEW_NAME" ] && [ -z "$GITHUB_REPO_DESCRIPTION" ] && [ -z "$GITHUB_REPO_PRIVATE" ] && [ -z "$GITHUB_REPO_HOMEPAGE" ]; then
    echo "Error: At least one of --name, --description, --private, or --homepage must be provided."
    usage
fi

function get_auth_user() {
  curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$GITHUB_API_URL/user" | jq -r '.login'
}

function check_if_repository_exists() {
  local owner="$1"
  local repo="$2"

  fetch=$(curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$GITHUB_API_URL/repos/$owner/$repo")
}

function update_repository() {
  local owner="$1"
  local repo="$2"

  update=$(curl -sL \
    -X PATCH \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$GITHUB_API_URL/repos/$owner/$repo" \
    -d "{
         \"name\": \"$GITHUB_REPO_NEW_NAME\",
         \"description\": \"$GITHUB_REPO_DESCRIPTION\",
         \"homepage\": \"$GITHUB_REPO_HOMEPAGE\",
         \"private\": \"$GITHUB_REPO_PRIVATE\"
       }")
}

echo "GitHub REST API - update repository"
echo ""

if [ -z "$GITHUB_REPO_OWNER" ]; then
  GITHUB_REPO_OWNER=$(get_auth_user)
fi

log "Checking if the provided repository exists..."

check_if_repository_exists "$GITHUB_REPO_OWNER" "$GITHUB_REPO_NAME"

HTTP_STATUS=$(
  echo "$fetch" | jq -r \
  '
  if .message == "Not Found" then
    "404"
  elif .message == "Bad credentials" then
    "401"
  else
    "200"
  end
  '
)

if [[ "$HTTP_STATUS" -eq 200 ]]; then
  log "Gathering repository metadata..."

  CURRENT_PROPERTIES=$(
    echo "$fetch" | jq -r '{current_properties: {Repository: .full_name, Description: .description, Private: .private, Homepage: .homepage}}'
  )

  printf '\n%s\n\n' "$CURRENT_PROPERTIES"

  log "Updating the following repository..."
  update_repository "$GITHUB_REPO_OWNER" "$GITHUB_REPO_NAME"

  UPDATED_PROPERTIES=$(
    echo "$update" | jq -r '{updated_properties: {Repository: .full_name, Description: .description, Private: .private, Homepage: .homepage}}'
  )

  printf '\n%s\n\n' "$UPDATED_PROPERTIES"

  log "Done!"
else
  log "Error: Failed to fetch repository with status code $HTTP_STATUS"
  exit 1
fi
