#!/bin/bash

set -euo pipefail

print_help() {
  cat <<EOF
Usage: $(basename "$0")

Force-remove all Docker containers on this host (docker rm -f).

Options:
  -h, --help    Show this help and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      printf 'ERROR: Unknown option: %s\n' "$1" >&2
      print_help >&2
      exit 1
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  printf 'ERROR: docker is not installed or not on PATH\n' >&2
  exit 1
fi

ids="$(docker ps -a --format '{{.ID}}')"
if [[ -n "$ids" ]]; then
  for container_id in $ids; do
    docker rm -f "$container_id" &>/dev/null
  done
  printf '%s\n' "All containers have been removed!"
else
  printf '%s\n' "No containers found!"
fi
