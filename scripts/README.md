# scripts

Top-level helpers that do not belong under a single `git/` or `github/`
topic. Run from the repo root.

| Script | Kind | Purpose |
|--------|------|---------|
| `migrate-repo-fresh.sh` | write | Copy a GitHub repo's default branch into a **new** repo as one fresh `main` commit (no history) |

## migrate-repo-fresh.sh

Clones the source over HTTPS (`git clone --depth 1`), rebuilds a single
fresh `main` commit, creates the destination, and pushes. Tokens are
never printed or stored in git config/remote (one-shot `http.extraHeader`).

### Auth

| Variable | Required | Purpose |
|----------|----------|---------|
| `TARGET_TOKEN` | preferred | Create the destination and push (REST + HTTPS) |
| `SOURCE_TOKEN` | optional | Clone a **private** source; when unset, clone anonymously |

Fallback: if `TARGET_TOKEN` is unset and `gh` is installed and
authenticated, create and push with `gh`.

```shell
export TARGET_TOKEN=...          # destination token; do not commit
# export SOURCE_TOKEN=...        # only if the source is private
./scripts/migrate-repo-fresh.sh owner-a/repo owner-b/repo
./scripts/migrate-repo-fresh.sh owner-a/repo owner-b/repo --public
```

### Token scopes (`TARGET_TOKEN`)

- **Classic PAT:** `repo` + `workflow` (needed to push `.github/workflows/`)
- **Fine-grained PAT:** Contents (read/write), Workflows (read/write), and
  Administration (to create the repository)

`SOURCE_TOKEN` needs read access to the source (classic `repo`, or
fine-grained Contents read).

Destination is private by default. The destination must not already exist;
the script never overwrites or force-pushes.
