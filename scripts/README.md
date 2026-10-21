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

Auth: `GH_TOKEN`, else `GITHUB_TOKEN`, else logged-in `gh`. See `--help`.
