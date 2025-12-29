# GitHub CLI

## Sources

- https://cli.github.com/
- https://cli.github.com/manual/

## Usage

### Installation

Download binary from [GitHub CLI](https://github.com/cli/cli) repository:
```shell
curl -fsSLo "gh_2.73.0_linux_amd64.tar.gz" "https://github.com/cli/cli/releases/download/v2.73.0/gh_2.73.0_linux_amd64.tar.gz"
```

Extract the tar file:
```shell
tar -xf gh_2.73.0_linux_amd64.tar.gz
```

Copy binary to your /usr/local/bin:
```shell
sudo cp gh_2.73.0_linux_amd64/bin/gh /usr/local/bin/
```

Get gh cli version:
```shell
gh version
```

### Uninstall

Delete binary in /usr/local/bin:
```shell
sudo rm -rf /usr/local/bin/gh
```

### Authentication

Authenticate against `github.com` by reading the token from a file:
```shell
gh auth login --with-token < mytoken.txt
```

Use this method when your token is stored in an environment variable (e.g., in CI/CD pipelines or scripts). The token is piped into the gh auth login command via standard input:
```shell
echo "$GITHUB_AUTH_TOKEN" | gh auth login --with-token
```

### Install GitHub CLI with Arkade

Run `arkade get` and follow the instructions:
```shell
arkade get gh
```

#### You must be wondering what is arkade?

[arkade - Open Source Marketplace For Developer Tools](https://github.com/alexellis/arkade)

## Reletad links

- [Exploring GitHub CLI: How to interact with GitHub’s GraphQL API endpoint](https://github.blog/developer-skills/github/exploring-github-cli-how-to-interact-with-githubs-graphql-api-endpoint/)
