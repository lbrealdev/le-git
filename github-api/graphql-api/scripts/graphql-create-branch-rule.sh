#!/bin/bash

set -euo pipefail

GITHUB_REPOSITORY="$1"

# Get the currently authenticated user.
function gh_graphql_get_owner() {
  GITHUB_OWNER=$(
  gh api graphql -f query='
    query {
      viewer {
        login
      }
    }' | jq -r '.data.viewer.login'
  )
}

# Get global node id from repository.
function gh_graphql_get_repository_id() {
  gh_graphql_get_owner
  REPOSITORY_ID=$(
  gh api graphql -F owner="$GITHUB_OWNER" -F repo="$GITHUB_REPOSITORY" -f query='
    query GetRepositoryId($owner: String!, $repo: String!) {
      repository(owner: $owner, name: $repo) {
        id
      }
    }' | jq -r '.data.repository.id'
  )
}

# Create the branch protection rule.
function gh_graphql_create_branch_protection() {
  gh_graphql_get_repository_id
  gh api graphql -F repositoryId="$REPOSITORY_ID" -F branchPattern="main" -f query='
    mutation CreateBranchProtection($repositoryId: ID!, $branchPattern: String!) {
      createBranchProtectionRule(input: {
        allowsDeletions: false
        allowsForcePushes: false
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
      }) {
        branchProtectionRule {
          creator { login, url }
          allowsDeletions
          blocksCreations
          pattern
        }
      }
    }'
}

gh_graphql_create_branch_protection
