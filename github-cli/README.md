# GitHub CLI

## Install GH cli on Linux

Download binary from [GH cli](https://github.com/cli/cli) repository:
```shell
curl -s -f -L "https://github.com/cli/cli/releases/download/v2.30.0/gh_2.30.0_linux_amd64.tar.gz" -o gh_2.30.0_linux_amd64.tar.gz
```

Extract the tar file:
```shell
tar -xf gh_2.30.0_linux_amd64.tar.gz
```

Copy binary to your /usr/local/bin:
```shell
cp gh_2.30.0_linux_amd64/bin/gh /usr/local/bin/
```

Get gh cli version:
```shell
gh version
```

#### Uninstall gh

Delete binary in /usr/local/bin:
```shell
rm -rf /usr/local/bin/gh
```


## Install GH with Arkade

Run `arkade get` and follow the instructions:
```shell
arkade get gh
```

#### You must be wondering what is arkade?

[arkade - Open Source Marketplace For Developer Tools](https://github.com/alexellis/arkade)
