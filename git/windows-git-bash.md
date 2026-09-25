# Git on Windows / Git Bash

Notes for **Git for Windows** and **Git Bash** (not a WSL-only setup).
Goal: keep LF in the repo, avoid surprise CRLF churn, and know where GCM
config lives.

## Line endings: recommended config

Prefer LF in the working tree and in the object store. On Windows that
usually means turning off automatic CRLF conversion:

```shell
# Global (all repos on this machine) — typical for Git Bash users
git config --global core.autocrlf false
git config --global core.eol lf
```

Local (one repo only) uses the same keys without `--global`:

```shell
git config --local core.autocrlf false
git config --local core.eol lf
```

Use **global** if you want the same behavior everywhere; use **local** to
override for a single project. Local wins over global for that repo.

Verify:

```shell
git config --show-origin --get core.autocrlf
git config --show-origin --get core.eol
```

## False “modified” files after EOL config changes

After you change `core.autocrlf` / `core.eol` (or add `.gitattributes`
elsewhere), Git may report many files as modified even though you did not
edit them — only the line endings differ from what the index expects.

If the diffs are **EOL-only** and you have **no real uncommitted edits**
on those paths, restore them:

```shell
# Prefer specific paths when you can
git restore -- path/to/file path/to/other

# Or everything currently dirty (dangerous if you have real edits)
git restore -- .
```

**Warning:** `git restore` discards uncommitted content on the paths you
name. Prefer restoring specific paths, and only when you are sure the
changes are EOL-only (`git diff` / `git diff --ignore-cr-at-eol` help).

## Optional `.gitattributes` (other projects)

A repo-level `.gitattributes` is **universal** (Windows, Linux, macOS). It
mainly reduces Windows CRLF pain by telling Git how to normalize text.

This repo (`le-git`) does **not** ship a root `.gitattributes` yet — treat
the block below as a **copy-paste example** for other projects:

```gitattributes
* text=auto eol=lf

# Common binary exceptions (add more as needed)
*.png binary
*.jpg binary
*.gif binary
*.ico binary
*.pdf binary
*.zip binary
```

## Credentials (GCM)

On Windows, Git Credential Manager (GCM) is the usual helper. Audit what
Git is using:

```shell
just git credential-audit
# or
./git/scripts/git-credential-helper-audit.sh
```

Details: [git/scripts/README.md](scripts/README.md).

## Checklist

1. Set `core.autocrlf=false` and `core.eol=lf` (global or local).
2. Verify with `git config --show-origin --get …`.
3. If status shows false dirty files, restore only EOL-only paths.
4. Optionally add a `.gitattributes` like the example above in **other**
   repos (not committed here yet).
