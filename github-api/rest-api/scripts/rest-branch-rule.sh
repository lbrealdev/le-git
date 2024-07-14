#!/bin/bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: ./$(basename "$0") <create|delete> <owner>/<repository-name> <branches>"
  exit 1
fi

GITHUB_API_URL="https://api.github.com"
GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"

ACTION="$1"
GITHUB_OWNER=$(echo "$2" | cut -d'/' -f1)
GITHUB_REPO=$(echo "$2" | cut -d'/' -f2)
GITHUB_BRANCH="$3"

# Create branch protection.
function create_branch_protection() {
  repo="$1"
  branch="$2"

  PROTECTION_PAYLOAD='{
    "required_status_checks": {
      "strict": true,
      "contexts": []
    },
    "enforce_admins": true,
    "required_pull_request_reviews": {
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true,
      "required_approving_review_count": 1
    },
    "restrictions": null
  }'

  curl -L \
    -X PUT \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$GITHUB_API_URL/repos/$GITHUB_OWNER/$repo/branches/$branch/protection" \
    -d "$PROTECTION_PAYLOAD"
}

function delete_branch_protection() {
  repo="$1"
  branch="$2"

  curl -L \
    -X DELETE \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$GITHUB_API_URL/repos/$GITHUB_OWNER/$repo/branches/$branch/protection"
}

IFS="," read -r -a branches <<< "$GITHUB_BRANCH"

if [ "$ACTION" == "create" ]; then
  echo "Creating branch protection rule ..."
  sleep 2
  for branch in "${branches[@]}"; do
    create_branch_protection "$GITHUB_REPO" "$branch"
  done
elif [ "$ACTION" == "delete" ]; then
  echo "Deleting branch protection rule ..."
  sleep 2
  for branch in "${branches[@]}"; do
    delete_branch_protection "$GITHUB_REPO" "$branch"
  done
else
  echo "Invalid option: $ACTION. Use 'create' or 'delete'."
fi
