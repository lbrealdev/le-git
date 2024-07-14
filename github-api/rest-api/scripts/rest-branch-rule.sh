#!/bin/bash

set -euo pipefail

ACTION="$1"
GITHUB_API_URL="https://api.github.com"
GITHUB_OWNER=$(echo "$2" | cut -d'/' -f1)
GITHUB_REPO=$(echo "$2" | cut -d'/' -f2)
GITHUB_BRANCH="$3"
GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"

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

if [ "$ACTION" == "create" ]; then
  echo "Creating branch protection rule ..."
  sleep 2
  create_branch_protection "$GITHUB_REPO" "$GITHUB_BRANCH"
elif [ "$ACTION" == "delete" ]; then
  echo "Deleting branch protection rule ..."
  sleep 2
  delete_branch_protection "$GITHUB_REPO" "$GITHUB_BRANCH"
else
  echo "Invalid option!"
fi
