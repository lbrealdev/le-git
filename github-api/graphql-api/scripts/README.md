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
