# git scripts

## setup-cc-gitconfig.sh

Prepare Git (Git Bash / Windows) for **AWS CodeCommit over HTTPS** using the
AWS CLI v2 credential helper — without the Git Credential Manager
username/password dialog.

### Why this exists

Corporate Git for Windows installs often set system:

```ini
[credential]
        helper = manager
```

That helper can intercept HTTPS auth and show a dialog, which gets in the way
of CodeCommit when you already authenticate through AWS CLI / SSO / IAM.

**Preferred stack for this team:**

- Git
- AWS CLI v2
- HTTPS remotes
- `aws codecommit credential-helper`

Example global helper (set in `~/.gitconfig` as part of your normal AWS/Git
setup; this script does not invent it for you, but will preserve it if already
present and may copy non-GCM helpers when merging from system):

```ini
[credential]
        helper = !aws codecommit credential-helper $@
```

**Not using SSH here** — SSH to CodeCommit is a valid option, but this workflow
is intentionally HTTPS-only for now.

**Not using [`git-remote-codecommit`](https://github.com/aws/git-remote-codecommit)**
(PyPI: [git-remote-codecommit](https://pypi.org/project/git-remote-codecommit/)):

- Extra Python dependency
- Last meaningful upstream activity around 2023
- Unnecessary when `git` + AWS CLI v2 already support CodeCommit HTTPS

### What the script does

1. **Check-only (default)** — report system/global/effective `credential.helper`,
   write permission on system gitconfig, and `GIT_CONFIG_NOSYSTEM` status.
2. **`--fix-system`** — if system gitconfig is writable, unset system
   `credential.helper` (removes `manager`).
3. **`--migrate`** — if system gitconfig is locked:
   - requires existing `~/.gitconfig` and `~/.bashrc` (does not create them)
   - merges system keys into global (keeps existing global values; skips duplicates)
   - skips GCM helpers (`manager`, `manager-core`, `git-credential-manager*`)
   - appends `export GIT_CONFIG_NOSYSTEM=1` to `~/.bashrc` if missing
   - prints reload instructions (`source ~/.bashrc` or reopen Git Bash)

With system GCM out of the way (or ignored via `GIT_CONFIG_NOSYSTEM`), HTTPS
clones/fetches can use the AWS CLI CodeCommit helper without a dialog.

### Policy

1. **Writable system gitconfig** → `--fix-system`
2. **Read-only system gitconfig** → `--migrate`

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
./git/scripts/setup-cc-gitconfig.sh

# show help
./git/scripts/setup-cc-gitconfig.sh --help

# happy path: remove system credential.helper
./git/scripts/setup-cc-gitconfig.sh --fix-system

# read-only system: merge into global + enable NOSYSTEM in ~/.bashrc
./git/scripts/setup-cc-gitconfig.sh --migrate

# custom backup directory
./git/scripts/setup-cc-gitconfig.sh --migrate --backup-dir ~/gitconfig-backups
```

Mutating flags back up system/global gitconfig into `~/gitconfig-backups/`
first.

After `--migrate`, reload the shell so `GIT_CONFIG_NOSYSTEM` takes effect:

```shell
source ~/.bashrc
# or close/reopen Git Bash
./git/scripts/setup-cc-gitconfig.sh
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | No effective `manager` / `manager-core` helper, or `--migrate` succeeded |
| 1 | Effective manager still active — see Recommendation (`--fix-system` or `--migrate`) |
| 2 | Usage error, missing `~/.gitconfig`/`~/.bashrc` for migrate, or unexpected failure |
