#!/bin/bash

# GitHub REST API
# https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#update-a-repository

set -euo pipefail

usage() {
  echo "Usage: $0 <repo-name> [--name <new-name>] [--description <description>] [--private <private>] [--homepage <homepage>]"
  exit 1
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

# Validate that both repository owner and name are provided.
# This handles cases where the input format is invalid, such as "owner/" or "/repo".
if [[ "$1" == */* ]]; then
  IFS='/' read -r GITHUB_REPO_OWNER GITHUB_REPO_NAME <<< "$1"

  if [[ -z "$GITHUB_REPO_OWNER" ]] || [[ -z "$GITHUB_REPO_NAME" ]]; then
    echo "Error: Invalid repository format. Expected 'owner/repo'."
    echo "Parsed values -> owner: '$GITHUB_REPO_OWNER', repo: '$GITHUB_REPO_NAME'"
    usage
  fi
else
  GITHUB_REPO_NAME="$1"
fi

shift

create_json_from_args() {
  local json='{'

  local args=("$@")
  local i=0

  while [ $i -lt ${#args[@]} ]; do
      case "${args[$i]}" in
          --name)
              json+="\"name\":\"${args[$((i+1))]}\""; i=$((i+2)) ;;
          --description)
              json+="\"description\":\"${args[$((i+1))]}\""; i=$((i+2)) ;;
          --private)
              json+="\"private\":${args[$((i+1))]}"; i=$((i+2)) ;;
          --homepage)
              json+="\"homepage\":\"${args[$((i+1))]}\""; i=$((i+2)) ;;
          *)
              echo "${args[$i]}"; exit 1 ;;
      esac

      if [ $i -lt ${#args[@]} ]; then
          json+=","
      fi
  done

  json+='}'
  echo "$json"
}

# Checks whether at least one argument was provided
# and ensures the total number of arguments is even.
if [ $# -lt 2 ] || [ $(( $# % 2 )) -ne 0 ]; then
  echo "Error: At least one of --name, --description, --private, or --homepage must be provided."
  usage
fi

# Parses supported flags and constructs the JSON payload accordingly.
create_json=""
if ! create_json=$(create_json_from_args "$@"); then
  echo "Error: Invalid parameter passed. Supported flags are --name, --description, --private, and --homepage."
  usage
fi

json_data="$create_json"

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
    -d "$json_data")
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
