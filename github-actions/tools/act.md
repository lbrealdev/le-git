# act - Run your GitHub Actions locally

## Installation

Download act prebuilt executable from release page:
```shell
curl -fsSLo "act_Linux_x86_64.tar.gz" "https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz"
```

After the download is completed, use tar to extract the binary:
```shell
tar -xf act_Linux_x86_64.tar.gz
```

Copy the binary to the execution directory:
```shell
cp act ~/.local/bin
```

Get act version:
```shell
act --version
```

Get `actrc` config file:
```shell
cat ~/.config/act/actrc
```

### Sources

- https://nektosact.com/
- https://github.com/nektos/act
- https://nektosact.com/installation/index.html
