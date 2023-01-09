#!/bin/bash

set -e

function disable() {
gh api graphql -f query='{
    repository(owner:"lbrealdev", name:"rust-ci") {
        branchProtectionRules(first:100)  {
            nodes {
                allowsDeletions,
                allowsForcePushes,
                blocksCreations,
                creator {
                    login,
                    url,
                    resourcePath,
                    avatarUrl
                },
                databaseId,
                dismissesStaleReviews,
                isAdminEnforced,
                lockAllowsFetchAndMerge,
                pattern,
                pushAllowances(first:100) {
                   nodes {
                     actor
                   },
                },
                repository {
                    createdAt,
                    description,
                    isInOrganization,
                    languages(first: 100) {
                        nodes { name }
                    },
                    name,
                    nameWithOwner,
                    owner { login },
                    primaryLanguage {
                        name
                    },
                    url,
                    updatedAt
                },
                requireLastPushApproval,
                requiredApprovingReviewCount,
                lockBranch
            }
        }
    }
}'
}

function get_branch_protection_rules() {
  gh api graphql -F owner="lbrealdev" -F repository="rust-ci" \
    -f query='
    query GetBranchProtectionRules($owner:String!, $repository:String!) {
      repository(owner: $owner, name: $repository) {
        branchProtectionRules(first: 10) {
          nodes {
            creator { login, url, resourcePath }
            pattern
            repository {
              createdAt
              description
              isInOrganization
              languages(first: 10) { nodes { name } }
              primaryLanguage { name }
              url
            }
          }
        }
      }
    }'
}

get_branch_protection_rules
