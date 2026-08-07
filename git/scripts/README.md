# git scripts

## check-gitconfig.sh

Git Bash helper to audit (and optionally remediate) a locked system
`credential.helper = manager` on Windows Git installs.

On many corporate machines, system gitconfig lives under Program Files and is
not writable. That system `manager` helper can interfere with flows such as
AWS CodeCommit.

### Policy

1. **Writable system gitconfig** — `--fix-system` unsets system `credential.helper`
2. **Read-only system gitconfig** — `--migrate`:
   - requires existing `~/.gitconfig` and `~/.bashrc` (does not create them)
   - merges system keys into global (keeps existing global values; skips duplicates)
   - skips GCM helpers (`manager`, `manager-core`, `git-credential-manager*`)
   - appends `export GIT_CONFIG_NOSYSTEM=1` to `~/.bashrc` if missing
   - prints reload instructions (`source ~/.bashrc` or reopen Git Bash)

Migration skips these `credential.helper` values:

- `manager`
- `manager-core`
- `manager-core.exe`
- `git-credential-manager*`

Other system keys (`core.*`, `http.*`, `init.*`, non-GCM helpers, etc.) are
copied into global when missing. Nothing is deleted from global.

### Usage

```shell
# check only (default)
./git/scripts/check-gitconfig.sh

# show help
./git/scripts/check-gitconfig.sh --help

# happy path: remove system credential.helper
./git/scripts/check-gitconfig.sh --fix-system

# read-only system: merge into global + enable NOSYSTEM in ~/.bashrc
./git/scripts/check-gitconfig.sh --migrate

# custom backup directory
./git/scripts/check-gitconfig.sh --migrate --backup-dir ~/gitconfig-backups
```

Mutating flags back up system/global gitconfig into `~/gitconfig-backups/`
first.

After `--migrate`, reload the shell so `GIT_CONFIG_NOSYSTEM` takes effect:

```shell
source ~/.bashrc
# or close/reopen Git Bash
./git/scripts/check-gitconfig.sh
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | No effective `manager` / `manager-core` helper, or `--migrate` succeeded |
| 1 | Effective manager still active (check-only / `--fix-system` path) |
| 2 | Usage error, missing `~/.gitconfig`/`~/.bashrc` for migrate, or unexpected failure |
