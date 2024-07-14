#!/bin/bash

set -euo pipefail

# Get the currently authenticated user.
function gh_api_get_owner() {
  GITHUB_OWNER=$(
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /user | jq -r '.login'
  )
}

# Create branch protection.
function gh_api_create_branch_protection() {
  repo="$1"
  branch="$2"

  gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$GITHUB_OWNER/$repo/branches/$branch/protection" \
    -F "required_status_checks=null" \
    -F "restrictions=null" \
    -F "enforce_admins=false" \
    -F "required_pull_request_reviews[required_approving_review_count]=1" \
    -F "required_linear_history=true" \
    -F "allow_force_pushes=false" \
    -F "allow_deletions=false" \
    -F "block_creations=true" \
    -F "required_conversation_resolution=true" \
    -F "lock_branch=true" \
    -F "allow_fork_syncing=true"
}


gh_api_get_owner
gh_api_create_branch_protection "$@"
