# GitHub Authentication - GitHub GPG Keys

### GPG commands

```shell
gpg --full-generate-key
```

```shell
gpg --list-secret-keys --keyid-format=long
```

```shell
gpg --armor --export <key-id>
```

### GPG troubleshooting

```shell
GIT_TRACE=1 git commit -m "test commit"
```

Errors:
```shell
$ git commit -am "feat: move yt-dlp guide to tools directory"
error: gpg failed to sign the data
fatal: failed to write commit object
```

// image

Source:

- [GitHub - Generating a new GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
