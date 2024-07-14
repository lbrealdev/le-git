# GitHub GraphQL API scripts

### Usage

Go to scripts directory:
```shell
cd github-api/graphql-api/scripts/
```

Get authenticated user info:
```shell
./graphql-user-info.sh
```

Get repository metadata:
```shell
./graphql-repository-info.sh <repository-name>
```

List branch protection rules:
```shell
./graphql-list-branch-rule.sh <repository-name>
```

Create a branch protection:
```shell
./graphql-create-branch-rule.sh <repository-name>
```
