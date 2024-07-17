# GitHub GraphQL API scripts

### Usage

Go to scripts directory:
```shell
cd github-api/graphql-api/scripts/
```

Get authenticated user info:
```shell
./gh-graphql-user-metadata.sh
```

Get legacy and next global ID:
```shell
./graphql-user-next-id.sh <login>
```

Get repository metadata:
```shell
./gh-graphql-repo-metadata.sh <owner>/<repository-name>
```

List branch protection rules:
```shell
./gh-graphql-list-branch-rule.sh <owner>/<repository-name>
```

Create a branch protection:
```shell
./gh-graphql-create-branch-rule.sh <owner>/<repository-name> <branch>
```

# Signing commit with GitHub GraphQL API

### Usage

Export GitHub PAT:
```shell
export GITHUB_AUTH_TOKEN="github-token"
```

Run graphql-sign-commit:
```shell
./graphql-sign-commit.sh -r "<owner>/<repository-name>" -p "<file|directory>"
```
**NOTE**: Run this script inside the repository you want to upload new files.


### Demo

1 - Create new repository.

2 - Clone new repository and move the files you want to upload to the new repository, it can be a file or directory, but must be within the repository directory.

3 - Export `GITHUB_AUTH_TOKEN`:
```shell
export GITHUB_AUTH_TOKEN="gha_****"
```

4 - Run the script:
```shell
./graphql-sign-commit.sh -r "gh-user/repo-to-upload" -p ".github"
```

**NOTE**: You can pass one or more files and directories as `-p "pyproject.toml, main.py"` or `-p ".github, tests"`.
