#!/bin/bash

set -e

gh api graphql -f query='{
    repository(owner:"owner", name:"repository") {
        branchProtectionRules(first:1)  {
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
