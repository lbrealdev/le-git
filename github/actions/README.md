# GitHub Actions

### Scripts

Self-hosted runner cleanup (destructive; inspect before running):

- [`scripts/runner-cleanup-workflow-dir.sh`](scripts/runner-cleanup-workflow-dir.sh) — empty `_work/`
- [`scripts/runner-cleanup-docker.sh`](scripts/runner-cleanup-docker.sh) — `docker rm -f` all containers

### Guides

- [Github Actions Workflows](github_actions_workflows.md)
- [Github Actions - self-hosted runners](github_actions_self_hosted_runner.md)

### GitHub Actions Labs

- [GitHub Actions Lab](https://github.com/guitarrapc/githubactions-lab)

### GitHub Actions Tools

- [act](tools/act.md)
- [zizmor](tools/zizmor.md)
- [wrkflw](tools/wrkflw.md)
- [claws](tools/claws.md)
- [gato](tools/gato.md)
- [gato-x](tools/gato-x.md)
- [octoscan](tools/octoscan.md)
- [raven](https://github.com/CycodeLabs/raven)
- [purplepanda](https://github.com/carlospolop/PurplePanda)
- [lotp](https://boostsecurityio.github.io/lotp/)
- [allstar](https://github.com/ossf/allstar)

### GitHub Actions Security

- [Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-for-github/actions/security-guides/security-hardening-for-github-actions)
- [How to Harden GitHub Actions: The Unofficial Guide](https://www.wiz.io/blog/github-actions-security-guide)
- [Application Security Cheat Sheet - GitHub Actions](https://0xn3va.gitbook.io/cheat-sheets/ci-cd/github/actions)
- [Action Advisor](https://app.stepsecurity.io/action-advisor)

### GitHub Actions Tutorials

- [How to Run Integration Tests with GitHub Service Containers](https://www.freecodecamp.org/news/how-to-run-integration-tests-with-github-service-containers/)

### GitHub Actions Blogs

- [ArtiPACKED: Hacking Giants Through a Race Condition in GitHub Actions Artifacts](https://unit42.paloaltonetworks.com/github-repo-artifacts-leak-tokens/)
- [GitHub Actions: Faster Python runs with cached virtual environments](https://adamj.eu/tech/2023/11/02/github-actions-faster-python-virtual-environments/)
- [Prefer tee -a, not >>, in CI](https://huonw.github.io/blog/2025/02/ci-tee/)
