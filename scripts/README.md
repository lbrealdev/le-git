# scripts

Top-level helpers that do not belong under a single `git/` or `github/`
topic. Run from the repo root.

| Script | Kind | Purpose |
|--------|------|---------|
| `migrate-repo-fresh.sh` | write | Copy a GitHub repo's default branch into a **new** repo as one fresh `main` commit (no history) |

Example:

```shell
./scripts/migrate-repo-fresh.sh owner-a/repo owner-b/repo
./scripts/migrate-repo-fresh.sh owner-a/repo owner-b/repo --public
```

Destination is private by default. The destination must not already exist;
the script never overwrites or force-pushes.
