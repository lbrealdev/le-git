#!/bin/bash

set -euo pipefail
#set -x

GITHUB_URL="https://github.com"
GITHUB_API_URL=${GITHUB_URL/https:\/\//https:\/\/api.}
GITHUB_TOKEN="$GITHUB_AUTH_TOKEN"

repo=""
paths=()
file_paths=()

while getopts ":r:u:" flag
do
    case "${flag}" in
      r)
        repo=${OPTARG}
        ;;
      u)
        paths+=("${OPTARG}")
        ;;
      \?)
        echo "Invalid option -$OPTARG" >&2
        exit 1
        ;;
    esac
done

input_path="${paths[*]-null}"

echo "$input_path"

exit 1

# Check input path
function check_input_path() {
    local input="$1"

    if [[ -f "$input" ]]; then
      file_paths+=("$input")
    elif [[ -d "$input" ]]; then
      file_paths+=("$input")
    else
      echo "Skipping non-file item: $input"
    fi
}

if [ "$input_path" != "null" ]; then
  for path in "${paths[@]}"; do
    check_input_path "$path"
  done

  changed_files_json=""
  for path in "${file_paths[@]}"; do
    if [[ -f "$path" ]]; then
      base64_content=$(base64 -w0 < "$path")
      changed_files_json+="{
             \"path\": \"$path\",
             \"contents\": \"$base64_content\"
          },
          "
    elif [[ -d "$path" ]]; then
      while IFS= read -r -d '' item
      do
        base64_content=$(base64 -w0 < "$item")
        changed_files_json+="{
            \"path\": \"$item\",
            \"contents\": \"$base64_content\"
          },
          "
      done < <(find "$path" -type f -print0)
    fi
  done

  changed_files_json="${changed_files_json%,
          }"
else
  echo "Empty!!"
  exit 1
fi

branch="main"
repo_nwo="$repo"
message_headline="signed commit via graphql API"
message_body="signed commit via graphql API"

remote_url=${GITHUB_URL/https:\/\/github.com/https:\/\/$GITHUB_TOKEN@github.com/$repo.git}
parent_sha=$(git ls-remote --refs "$remote_url" main | awk '{print $1}')

graphql_request='{
  "query": "mutation ($input: CreateCommitOnBranchInput!) {
    createCommitOnBranch(input: $input) {
      commit {
        url
        additions
        changedFilesIfAvailable
        committedDate
        authoredDate
        deletions
        committer {
          name
          date
          email
        }
        oid
        signature {
          isValid
          signer {
            login
          }
        }
      }
    }
  }",
  "variables": {
    "input": {
      "branch": {
        "repositoryNameWithOwner": "'"$repo_nwo"'",
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

# DEBUG
#echo "$graphql_request"
#echo "FINAL JSON REQUEST"

if [[ -e "request.json" ]]; then
  echo "Cleaning up old request file ..."
  rm -rf request.json
  sleep 2
fi

echo "Generating new request json file ..."
sleep 2
echo "$graphql_request" > request.json

printf "\n"

create_commit=$(curl -sL \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "$GITHUB_API_URL/graphql" \
  -d "@request.json")

echo "$create_commit" | jq .

rm -rf request.json
