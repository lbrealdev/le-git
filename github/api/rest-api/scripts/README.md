# GitHub REST API scripts

### Usage

The `gh-rest-*.sh` scripts use `gh cli` behind the scenes, make sure you have `gh` installed.

Go to scripts directory:
```shell
cd github-api/rest-api/scripts/
```

List branch protection rules:
```shell
./gh-rest-list-branch-rule.sh <owner>/<repository-name>
```

Create a branch protection:
```shell
./gh-rest-create-branch-rule.sh <owner>/<repository-name> <branch>
```

The `rest-*.sh` is curl, so I understand this won't be a problem.

Run this script to create or delete branch protection rules:
```shell
export GITHUB_AUTH_TOKEN="<github-token>"

./rest-branch-rule.sh <create|delete> <owner>/<repository-name> <branches>
```
**NOTE**: The last argument `<branches>` can be passed like `main` or `"main,develop"`.


### Update Repository

```shell
just rest update-repo-test repo-name --name "new-name" --description "description" --private false --homepage "url"
```
