# git scripts

## check-gitconfig.sh

Git Bash helper to audit (and optionally remediate) a locked system
`credential.helper = manager` on Windows Git installs.

On many corporate machines, system gitconfig lives under Program Files and is
not writable. That system `manager` helper can interfere with flows such as
AWS CodeCommit. This script prefers fixing or migrating config; it treats
`GIT_CONFIG_NOSYSTEM` as a last-resort fallback only.

### Policy

1. **Writable system gitconfig** — unset system `credential.helper`
2. **Read-only system gitconfig** — copy system keys into global (skip GCM
   helpers), then set a global empty `credential.helper` reset
3. **Fallback only** — if `manager` is still effective, print instructions for
   `GIT_CONFIG_NOSYSTEM=1` (do not enable it by default)

Migration skips these `credential.helper` values:

- `manager`
- `manager-core`
- `manager-core.exe`
- `git-credential-manager*`

Other system keys (`core.*`, `http.*`, `init.*`, non-GCM helpers, etc.) are
copied into global when missing.

### Usage

```shell
# check only (default)
./git/scripts/check-gitconfig.sh

# happy path: remove system credential.helper
./git/scripts/check-gitconfig.sh --fix-system

# read-only system: migrate to global + empty helper reset
./git/scripts/check-gitconfig.sh --migrate

# custom backup directory
./git/scripts/check-gitconfig.sh --migrate --backup-dir ~/gitconfig-backups
```

Mutating flags back up system/global gitconfig into `~/gitconfig-backups/`
first.

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | No effective `manager` / `manager-core` helper |
| 1 | Effective manager still active (fallback instructions printed) |
| 2 | Usage error, git missing, or unexpected failure |

Warnings (still exit `0`) when OK only because `GIT_CONFIG_NOSYSTEM` is set,
or when it is set in the current shell/Bash profile but not as a Windows User
environment variable.

### Fallback (only if needed)

```shell
export GIT_CONFIG_NOSYSTEM=1
echo 'export GIT_CONFIG_NOSYSTEM=1' >> ~/.bashrc
```

Windows User env (no Administrator), PowerShell:

```powershell
[System.Environment]::SetEnvironmentVariable('GIT_CONFIG_NOSYSTEM', '1', 'User')
```

Reopen the shell and re-run the script.
