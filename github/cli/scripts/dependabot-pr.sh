#!/usr/bin/env bash

set -euo pipefail

print_help() {
  cat <<EOF
Usage: $0 [options] <owner/repo>

Merge all mergeable dependabot PRs in the specified repository.

Arguments:
  owner/repo    GitHub repository in owner/repo format

Options:
  -h, --help    Show this help message and exit

Examples:
  $0 cli/cli
  $0 --help
EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      print_help
      exit 0
      ;;
  esac
done

if [[ $# -eq 0 ]]; then
  print_help
  exit 1
fi

REPO="$1"

# Check if gh CLI is authenticated
if ! gh auth status &>/dev/null; then
  echo "Error: GitHub CLI (gh) is not authenticated." >&2
  echo "Please run: gh auth login" >&2
  exit 1
fi

PR_DATA=$(gh pr ls -R "$REPO" -S "author:app/dependabot" --json number,mergeStateStatus --jq '.[]' 2>&1) || {
  echo "Error: Failed to list PRs for repository '$REPO'." >&2
  echo "Please check that the repository exists and you have access to it." >&2
  exit 1
}

if [[ -z "$PR_DATA" ]]; then
  echo "No dependabot PRs found."
  exit 0
fi

MERGE_COUNT=0
BLOCKED_COUNT=0
blocked=()

while read -r pr; do
  [[ -z "$pr" ]] && continue

  number=$(echo "$pr" | jq -r '.number')
  status=$(echo "$pr" | jq -r '.mergeStateStatus')

  if [[ "$status" == "CLEAN" ]]; then
    printf 'Merging PR #%s...\n' "$number"
    gh pr merge "$number" -R "$REPO" --merge --delete-branch
    ((MERGE_COUNT++)) || true
  else
    blocked+=("- #${number}: ${status}")
    ((BLOCKED_COUNT++)) || true
  fi
done <<<"$PR_DATA"

if [[ $MERGE_COUNT -gt 0 ]]; then
  printf '\nMerged: %s PR(s)\n' "$MERGE_COUNT"
fi

if [[ $BLOCKED_COUNT -gt 0 ]]; then
  printf '\nBlocked PRs:\n'
  printf '%s\n' "${blocked[@]}"
  printf 'Blocked: %s PR(s)\n' "$BLOCKED_COUNT"
fi
