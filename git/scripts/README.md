# git scripts

Read-only helpers for day-to-day Git. Run from the repo root via `just`,
or execute the scripts directly.

```shell
just --list git
just git credential-audit
just git default-branch
```

| Script | Kind | Purpose |
|--------|------|---------|
| `git-credential-helper-audit.sh` | read-only | Report `credential.helper` at system/global/local/effective scopes; flag GCM manager helpers |
| `git-default-branch-check.sh` | read-only | Compare current branch to `origin/HEAD`; hint when both `main` and `master` exist |

AWS CodeCommit HTTPS gitconfig setup (system GCM, `--fix-system` /
`--migrate`) lives in `lbrealdev/0k-aws` under `dev-tools/codecommit/`.
