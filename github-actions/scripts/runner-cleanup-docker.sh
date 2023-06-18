#!/bin/bash

set -eo pipefail

# Get all containers by .ID
function docker_get_container_id() {
  docker_container_ids=$(docker ps -a --format '{{.ID}}')
}

# Force-remove a container regardless of its state
function docker_remove_container_id() {
  local container_id=$1
  docker rm -f "$container_id" &>/dev/null
}

function main() {
  docker_get_container_id
  # Remove all containers.
  if [ -n "$docker_container_ids" ]; then
    for container_id in $docker_container_ids; do
      docker_remove_container_id "$container_id"
    done
    echo "All containers have been removed!"
  else
    echo "No containers found!"
  fi
}

main
