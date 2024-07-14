# GitHub REST API scripts

### Usage

`gh-rest-*.sh` scripts use `gh cli` in the background, ensure either have `gh` installed.

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

```shell
./rest-create-branch-rule.sh <owner>/<repository-name> main
```
