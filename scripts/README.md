# scripts

Top-level helpers that do not belong under a single `git/` or `github/`
topic. Run from the repo root.

| Script | Kind | Purpose |
|--------|------|---------|
| `migrate-repo-fresh.sh` | write | Copy a **public** GitHub repo's default branch into a **new** repo as one fresh `main` commit (no history) |

## migrate-repo-fresh.sh

Source is cloned anonymously over HTTPS (`git clone --depth 1`). Only the
destination needs credentials.

Preferred auth: export `DST_TOKEN` (GitHub token that can create the
destination). The script creates the repo via the REST API and pushes
over HTTPS without printing the token or storing it in git config/remote.

Fallback: if `DST_TOKEN` is unset and `gh` is installed and authenticated,
create and push with `gh`.

```shell
export DST_TOKEN=...   # destination account token; do not commit
./scripts/migrate-repo-fresh.sh owner-a/repo owner-b/repo
./scripts/migrate-repo-fresh.sh owner-a/repo owner-b/repo --public
```

Destination is private by default. The destination must not already exist;
the script never overwrites or force-pushes.
