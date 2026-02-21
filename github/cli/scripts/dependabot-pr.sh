#!/usr/bin/env bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <owner/repo>"
  echo "  Merge all mergeable dependabot PRs in the specified repository."
  exit 1
fi

REPO="$1"

PR_DATA=$(gh pr ls -R "$REPO" -S "author:app/dependabot" --json number,mergeStateStatus --jq '.[]')

if [[ -z "$PR_DATA" ]]; then
  echo "No dependabot PRs found."
  exit 0
fi

MERGE_COUNT=0
BLOCKED_COUNT=0
BLOCKED_LIST=""

while read -r pr; do
  [[ -z "$pr" ]] && continue

  number=$(echo "$pr" | jq -r '.number')
  status=$(echo "$pr" | jq -r '.mergeStateStatus')

  if [[ "$status" == "CLEAN" ]]; then
    echo "Merging PR #$number..."
    gh pr merge "$number" -R "$REPO" --merge --delete-branch
    ((MERGE_COUNT++))
  else
    BLOCKED_LIST+="- #$number: $status\n"
    ((BLOCKED_COUNT++))
  fi
done <<< "$PR_DATA"

if [[ $MERGE_COUNT -gt 0 ]]; then
  echo -e "\nMerged: $MERGE_COUNT PR(s)"
fi

if [[ $BLOCKED_COUNT -gt 0 ]]; then
  echo -e "\nBlocked PRs:"
  echo -e "$BLOCKED_LIST"
  echo "Blocked: $BLOCKED_COUNT PR(s)"
fi
