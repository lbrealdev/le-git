# le-git — Development Guide

Personal Git/GitHub notes and helper scripts (`legit` = Let's Explain Git
and GitHub). Prefer small, focused changes over wholesale rewrites of
older API POCs.

## Git conventions

- Branch from `master`; do not commit or push directly to `master`
- Use [Conventional Commits](https://www.conventionalcommits.org/), for
  example `docs:`, `fix(scripts):`, `feat(git):`, `chore(ci):`
- Keep commits focused; one logical change per commit when practical
- Open work as a PR on `lbrealdev/le-git` (do not file GitHub issues)

## Layout

- `git/` — command notes (`README.md`, `git-tricks.md`) and helpers in
  `git/scripts/`
- `github/` — GitHub topic notes plus REST/GraphQL/CLI/Actions scripts
- Root [`justfile`](justfile) modules: `rest`, `gql`, `git`

AWS CodeCommit HTTPS gitconfig (GCM / credential-helper migrate) lives in
`lbrealdev/0k-aws` under `dev-tools/codecommit/`. Do not re-add it here.

## Scripts

- Use `#!/bin/bash` and `set -euo pipefail` (some older helpers use
  `#!/usr/bin/env bash`; new scripts should follow this file)
- Every new `*.sh` must support `--help` / `-h` (print usage and exit 0)
- `--help` / usage text must not list dependencies; check tools at runtime
- Prefer read-only helpers; write scripts should make side effects obvious
  and support `--dry-run` where practical
- Quote expansions passed to `git`, `gh`, `curl`, `jq`, and `printf`
- Errors and usage go to stderr; data/tables go to stdout so output can be
  piped
- Check `command -v git` (and `gh` / `jq` / `curl` when used) before the
  first call; fail with a clear message

Leave `github/api/**/poc/` and other historical helpers alone unless the
task is to fix a real bug in them.

### Argument parsing

- `while [[ $# -gt 0 ]]; do case $1 in ... esac; done` then `main`
- Unknown flags: print error + usage to stderr, exit 1 (or 2 for usage)
- Mutually exclusive flags should be rejected explicitly
- Keep `--help` line width at 80 columns or less

### Printing and logging

Config paths, remotes, branch names, and other caller/config-derived
strings are untrusted for terminal output.

- Do not `echo -e` (or `echo -en`) with those strings: `\n`, `\e`, `\c`
  and friends are interpreted even when the expansion is quoted
- Emit data with `printf '%s'` (or `printf '%s\n'`)
- Color only when stdout is a TTY (`[ -t 1 ]`); piped output stays pure
  text
- Never print tokens or credentials in full

### Testing

Before opening a PR that touches scripts:

- `just check` (`bash -n` all `*.sh`; `shellcheck` on `git/scripts/` when
  `shellcheck` is on `PATH`)
- `bash -n path/to/script.sh`
- `shellcheck path/to/script.sh` when `shellcheck` is on `PATH` (zero
  findings for new helpers)

CI runs the same `bash -n` pass and shellchecks `git/scripts/*.sh`.

## Docs

- Root `README.md` is the map; directory `README.md` files index that
  area
- New helpers get a bullet in `git/scripts/README.md` (or the area's
  `scripts/README.md`) with **read-only** vs **write**
- Do not put credentials, PATs, or live account IDs in docs; sanitize
  examples

## Commands

```bash
just --list
just --list git
just --list rest
just --list gql
just git credential-audit
just git default-branch
just check
just setup          # pre-commit install
```
