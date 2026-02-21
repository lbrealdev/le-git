#!/ust/bin/env bash

# Set the pipefail
set -o pipefail

# Set the variable to the workflow directory path.
GITHUB_ACTIONS_WORKFLOW_DIR="/home/ec2-user/actions-runner/_work/"

function cleanup_github_actions_workflow_dir() {
  # Check if the workflow directory exists.
  if [ -d "$GITHUB_ACTIONS_WORKFLOW_DIR" ]; then
    # Check if the directory is empty.
    if [ -z "$(ls -A $GITHUB_ACTIONS_WORKFLOW_DIR)" ]; then
      # If the directory is empty, print a message and exit.
      echo "Github Action workflow directory exists and is empty!"
      exit 0
    else
      # If the directory is not empty, delete it.
      echo "Github Actions workflow directory exists and is not empty!"
      echo "Cleaning up the Github Actions workflow directory ..."
      rm -rf "$GITHUB_ACTIONS_WORKFLOW_DIR"*
      exit 0
    fi
  # If the directory does not exists, print a message and exit.
  else
    echo "Github Actions workflow directory does not exist!"
    exit 0
  fi
}

# Call function
cleanup_github_actions_workflow_dir
