# GitHub GraphQL API scripts

### Usage

Go to scripts directory:
```shell
cd github-api/graphql-api/scripts/
```

Get authenticated user info:
```shell
./gh-graphql-user-info.sh
```

Get repository metadata:
```shell
./gh-graphql-repository-info.sh <repository-name>
```

List branch protection rules:
```shell
./gh-graphql-list-branch-rule.sh <owner>/<repository-name>
```

Create a branch protection:
```shell
./gh-graphql-create-branch-rule.sh <owner>/<repository-name> <branch>
```
