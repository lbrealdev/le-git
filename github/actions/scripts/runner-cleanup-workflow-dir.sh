#!/bin/bash

set -euo pipefail

DEFAULT_DIR="/home/ec2-user/actions-runner/_work/"

print_help() {
  cat <<EOF
Usage: $(basename "$0") [DIR]

Remove contents of a GitHub Actions self-hosted runner _work directory.
Default: ${DEFAULT_DIR}

Options:
  -h, --help    Show this help and exit
EOF
}

DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    -*)
      printf 'ERROR: Unknown option: %s\n' "$1" >&2
      print_help >&2
      exit 1
      ;;
    *)
      if [[ -n "$DIR" ]]; then
        printf 'ERROR: unexpected argument: %s\n' "$1" >&2
        print_help >&2
        exit 1
      fi
      DIR="$1"
      shift
      ;;
  esac
done
DIR="${DIR:-$DEFAULT_DIR}"

if [[ ! -d "$DIR" ]]; then
  printf '%s\n' "GitHub Actions workflow directory does not exist!"
  exit 0
fi

shopt -s nullglob
entries=("${DIR%/}"/*)
if ((${#entries[@]} == 0)); then
  printf '%s\n' "GitHub Action workflow directory exists and is empty!"
  exit 0
fi

printf '%s\n' "GitHub Actions workflow directory exists and is not empty!"
printf '%s\n' "Cleaning up the GitHub Actions workflow directory ..."
rm -rf "${entries[@]}"
