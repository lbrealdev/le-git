# le-git

**le-git** (*legit*) — **L**et's **E**xplain **Git** and GitHub.

Personal notes, guides, and helper scripts for day-to-day Git and GitHub work.
Topics get updated as I dig into them — not a complete reference.

## Quick start

Scripts are wired through [`just`](https://github.com/casey/just):

```shell
just --list
just --list rest
just --list gql
```

Example:

```shell
just rest repo-branch-rule create my-repo main
just gql next-id <github-login>
```

## Contents

### Git

- [Git commands](git/README.md)
- [Tricks and tips](git/git-tricks.md)

### GitHub

- [AI](github/ai/README.md)
- [Actions](github/actions/README.md)
- [API](github/api/README.md)
  - [REST](github/api/rest-api/README.md) · [scripts](github/api/rest-api/scripts/README.md)
  - [GraphQL](github/api/graphql-api/README.md) · [scripts](github/api/graphql-api/scripts/README.md)
- [Apps](github/apps/README.md)
- [Authentication](github/auth/README.md)
  - [SSH auth key](github/auth/github_ssh_key.md)
  - [SSH signing key](github/auth/github_ssh_signing_key.md)
  - [GPG key](github/auth/github_gpg_key.md)
- [Blogs](github/blogs/README.md)
- [CLI](github/cli/README.md)
- [Documentation](github/docs/README.md)
- [Security](github/security/README.md)

## Writing helpers

- [Tables Generator](https://www.tablesgenerator.com/markdown_tables)
- [readme.so](https://readme.so/)
- [gitignore.io](https://www.toptal.com/developers/gitignore)
