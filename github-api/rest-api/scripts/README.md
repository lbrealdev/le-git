# GitHub REST API scripts

### Usage

The `gh-rest-*.sh` scripts use `gh cli` behind the scenes, make sure you have `gh` installed.

Go to scripts directory:
```shell
cd github-api/rest-api/scripts/
```

List branch protection rules:
```shell
./gh-rest-list-branch-rule.sh <repository-name>
```

Create a branch protection:
```shell
./gh-rest-create-branch-rule.sh <repository-name> main
```

The `rest-*.sh` is curl, so I understand this won't be a problem.

```shell
./rest-create-branch-rule.sh <owner>/<repository-name> main
```
