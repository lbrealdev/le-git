#!/bin/bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: ./$(basename "$0") <owner>/<repository-name> <branches>"
  exit 1
fi

GITHUB_OWNER=$(echo "$1" | cut -d'/' -f1)
GITHUB_REPO=$(echo "$1" | cut -d'/' -f2)
GITHUB_BRANCH="$2"
GLOBAL_ID="U_kgDOArBS9w"

# Get global node id from repository.
function gh_graphql_get_repository_id() {
  repo="$1"

  REPO_NODE_ID=$(
  gh api graphql -F owner="$GITHUB_OWNER" -F repo="$repo" -f query='
    query GetRepositoryId($owner: String!, $repo: String!) {
      repository(owner: $owner, name: $repo) {
        id
      }
    }' | jq -r '.data.repository.id'
  )
}

# Create the branch protection rule.
function gh_graphql_create_branch_protection() {
  repo_id="$1"
  branch="$2"
  id="$3"

  gh api graphql \
    -F repositoryId="$repo_id" \
    -F branchPattern="$branch" \
    -F globalId="$id" \
    -f query='
    mutation CreateBranchProtection($repositoryId: ID!, $branchPattern: String!, $globalId: ID!) {
      createBranchProtectionRule(input: {
        allowsDeletions: false
        allowsForcePushes: true
        blocksCreations: true
        dismissesStaleReviews: true
        isAdminEnforced: false
        pattern: $branchPattern
        repositoryId: $repositoryId
        requiresApprovingReviews: true
        requiredApprovingReviewCount: 1
        requiresCodeOwnerReviews: false
        requiresStatusChecks: true
        requiresStrictStatusChecks: true
        restrictsReviewDismissals: false
        requiresConversationResolution: false
        requiresCommitSignatures: false
        bypassForcePushActorIds: [$globalId]
      }) {
        branchProtectionRule {
          creator { login, url }
          allowsDeletions
          allowsForcePushes
          blocksCreations
          pattern
        }
      }
    }'
}

IFS="," read -r -a branches <<< "$GITHUB_BRANCH"

gh_graphql_get_repository_id "$GITHUB_REPO"

for BRANCH in "${branches[@]}"; do
  gh_graphql_create_branch_protection "$REPO_NODE_ID" "$BRANCH" "$GLOBAL_ID"
done
