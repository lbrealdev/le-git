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

Auth is never mixed:

- Per-side: set `SOURCE_TOKEN` and `TARGET_TOKEN` (transfer: `SOURCE_TOKEN`
  only). `GH_TOKEN`, `GITHUB_TOKEN`, and `gh` are ignored.
- Shared: set neither; one token from `GH_TOKEN`, else `GITHUB_TOKEN`, else
  `gh auth token`.

To use the `gh` login on one side, pass it explicitly
(`TARGET_TOKEN="$(gh auth token)"`).

Transfer needs a classic PAT or the `gh` token; fine-grained tokens cannot
call the transfer API.

Token permissions:

- transfer: classic `repo` scope and admin on the source
- `--mirror` / `--single-commit` source: read the source (contents, metadata)
- `--mirror` / `--single-commit` target: create the target and push
  (administration, contents)

`--single-commit` writes the new commit as
`gh-repo-migrate <gh-repo-migrate@users.noreply.github.com>` unless
`--host-identity` is set (then the host `git` `user.name` / `user.email`).
