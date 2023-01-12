#!/bin/bash

set -euo pipefail

# Get the currently authenticated user.
function gh_graphql_get_owner() {
  gh api graphql -f query='
    query {
      viewer {
        name
        login
        url
        bio
      }
    }'
}

gh_graphql_get_owner
