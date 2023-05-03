# GitHub CLI

### Install gh on Linux

Download binary from github:
```shell
curl -s -f -L "https://github.com/cli/cli/releases/download/v2.28.0/gh_2.28.0_linux_amd64.tar.gz" -o gh_2.28.0_linux_amd64.tar.gz
```

Extract the tar file:
```shell
tar -xf gh_2.28.0_linux_amd64.tar.gz
```

Copy binary to your /usr/local/bin:
```shell
cp gh_2.28.0_linux_amd64/bin/gh /usr/local/bin/
```

Get gh cli version:
```shell
gh version
```

### Uninstall gh

Delete binary in /usr/local/bin:
```shell
rm -rf /usr/local/bin/gh
```
