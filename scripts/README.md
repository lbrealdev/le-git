# scripts

Top-level helpers not tied to one `git/` or `github/` topic.

| Script | Kind | Purpose |
|--------|------|---------|
| `gh-repo-migrate.sh` | write | Move a GitHub repo (native transfer, `--mirror`, or `--single-commit`) |

```shell
./scripts/gh-repo-migrate.sh acme/widget new-co
./scripts/gh-repo-migrate.sh acme/widget new-co --mirror -n
./scripts/gh-repo-migrate.sh acme/widget --single-commit --public -y
```

Auth: `SOURCE_TOKEN` / `TARGET_TOKEN`, else `GH_TOKEN`, else `GITHUB_TOKEN`, else
logged-in `gh`. See `--help`.

`--single-commit` writes the new commit as
`gh-repo-migrate <gh-repo-migrate@users.noreply.github.com>` unless
`--host-identity` is set (then the host `git` `user.name` / `user.email`).
