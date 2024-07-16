#!/bin/bash

#set -euo pipefail

GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"

file_paths=()
dir_with_files=()

while getopts ":r:p:" opt; do
  case "$opt" in
    r)
      REPO="$OPTARG"
      ;;
    p)
      IFS=', ' read -ra changed_files <<< "${OPTARG:-}"
      ;;
    \?)
      echo "Invalid option -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [ "${#changed_files[@]}" -eq 0 ]; then
  echo "No file or directory specified."
  exit 1
fi

# Check if path is file or directory
# Do not pass absolute path.
for file in "${changed_files[@]}"; do
  if [[ -f "$file" ]]; then
    file_paths+=("$file")
  elif [[ -d "$file" ]]; then
    if [ -z "$(ls -A "$file")" ]; then
      echo "Empty directory!"
      exit 0
    else
      dir_with_files+=("$file")
      file_paths+=($(ls -d "$file"/*))
    fi
  else
    echo "The input file does not exist!"
    exit 1
  fi
done

# Debug files
#if [ "${#file_paths[@]}" -gt 0 ]; then
#  echo "Files:"
#  for file in "${file_paths[@]}"; do
#    echo "$file"
#  done
#fi

changed_files_json=""
for file in "${file_paths[@]}"; do
  changed_files_json+="{
            \"path\": \"$file\",
            \"contents\": \"$(base64 -w0 < "$file")\"
         },
         "
done

changed_files_json="${changed_files_json%,
         }"

# Debug changed files json
#echo "$changed_files_json"

repo="$REPO"
branch="main"
message_headline="signed commit via graphql API"
message_body="signed commit via graphql API"

parent_sha=$(git ls-remote --refs origin main | cut -f1)

graphql_request='{
  "query": "mutation ($input: CreateCommitOnBranchInput!) {
    createCommitOnBranch(input: $input) {
      commit {
        url
        additions
        changedFilesIfAvailable
        committedDate
      }
    }
  }",
  "variables": {
    "input": {
      "branch": {
        "repositoryNameWithOwner": "'"$repo"'",
        "branchName": "'"$branch"'"
      },
      "message": {
        "headline": "'"$message_headline"'",
        "body": "'"$message_body"'"
      },
      "fileChanges": {
        "additions": [
          '"$changed_files_json"'
        ]
      },
      "expectedHeadOid": "'"$parent_sha"'"
    }
  }
}'

# Debug graphql request json
echo "$graphql_request"

if [[ -e "request.json" ]]; then
  echo -e "\nCleaning up old request file ..."
  rm -rf request.json
  sleep 2
fi

echo "Generating new graphql request json file ..."
sleep 2
echo "$graphql_request" > request.json

printf "\n"

create_commit=$(curl -sL \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/graphql \
  -d "@request.json")

echo "$create_commit" | jq .

rm -rf request.json
