#!/bin/bash

set -euo pipefail

GITHUB_OWNER="lbrealdev"
GITHUB_REPOSITORY="$1"

#function gh_api_repository_id() {
#  repository_id=$(gh api -H "Accept: application/vnd.github+json" "/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}" | jq -r '.node_id')
#}

function gh_graphql_repository_id() {
  repository_id=$(gh api graphql -F owner="$GITHUB_OWNER" -F repo="$GITHUB_REPOSITORY" -f query='
  query GetRepositoryId($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
        id
    }
  }' | jq -r '.data.repository.id')
}

function gh_graphql_branch_protection() {
  gh_graphql_repository_id
  gh api graphql -F repositoryId="$repository_id" -F branchPattern="main" -f query='
  mutation ($repositoryId: ID!, $branchPattern: String!) {
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
        restrictsReviewDismissals: false
    }) {
        branchProtectionRule {
            allowsDeletions
            allowsForcePushes
            blocksCreations
            dismissesStaleReviews
            isAdminEnforced
            pattern
            requiresApprovingReviews
            requiredApprovingReviewCount
            requiresCodeOwnerReviews
            requiresStatusChecks
            restrictsReviewDismissals
        }
    }
  }'
}

gh_graphql_branch_protection
