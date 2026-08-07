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
- HTTPS remotes (not console **HTTPS (GRC)**)
- `aws codecommit credential-helper`

Preferred `~/.gitconfig` shape when GCM may still be present (URL-scoped helper
+ `UseHttpPath`, as in the AWS Windows HTTPS setup **Important** note). This
script does not write these entries for you; set them as part of normal AWS/Git
setup. It will preserve existing non-GCM helpers when merging from system.

Two region examples:

```ini
[credential "https://git-codecommit.us-east-1.amazonaws.com"]
        helper = !aws codecommit credential-helper $@
        UseHttpPath = true

[credential "https://git-codecommit.us-east-2.amazonaws.com"]
        helper = !aws codecommit credential-helper $@
        UseHttpPath = true
```

Or cover CodeCommit hosts with a wildcard:

```ini
[credential "https://git-codecommit.*.amazonaws.com"]
        helper = !aws codecommit credential-helper $@
        UseHttpPath = true
```

Git Bash note: when setting via `git config`, use **single quotes** (not double
quotes), per the AWS Windows HTTPS docs. Example:

```shell
git config --global credential.https://git-codecommit.*.amazonaws.com.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
```

**Not using SSH here** — SSH to CodeCommit is a valid option, but this workflow
is intentionally HTTPS-only for now.

**Not using HTTPS (GRC)** — Amazon’s console label for
[`git-remote-codecommit`](https://github.com/aws/git-remote-codecommit)
(PyPI: [git-remote-codecommit](https://pypi.org/project/git-remote-codecommit/)):

- Extra Python dependency
- Last meaningful upstream activity around 2023
- Unnecessary when `git` + AWS CLI v2 already support CodeCommit HTTPS with the
  credential helper above

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

### References

- [Setting up for AWS CodeCommit](https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up.html)
- [HTTPS with git-remote-codecommit (GRC)](https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-git-remote-codecommit.html)
- [HTTPS on Linux/macOS/Unix (credential helper)](https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-https-unixes.html)
- [HTTPS on Windows (credential helper)](https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-https-windows.html)
