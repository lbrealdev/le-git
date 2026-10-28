# Github Actions - Self-hosted runners

A machine you own that registers itself to a repository (or an organization runner
group), runs **one job**, then disappears. The alternative to a GitHub-hosted runner,
and the escape hatch when hosted minutes stop being available — a metered private repo,
an outage, or an account-level billing block.

Implementation path (VM, systemd units, loop script, isolation):
[`selfhost-plans`](https://github.com/lbrealdev/selfhost-plans/tree/main/docs/github-actions-runner).

---

## Registration: plan tier decides the model

| | Organization-level | Repository-level |
| --- | --- | --- |
| Endpoint | `/orgs/{org}/actions/runners/generate-jitconfig` | `/repos/{owner}/{repo}/actions/runners/generate-jitconfig` |
| Needs a runner group | yes | yes, always id `1` |
| Plan requirement | **GitHub Team** | none |
| Token scope | org *Self-hosted runners* | repo *Administration: read/write* |

Runner groups are a Team-plan feature. On a Free organization the API returns `403`
(`You must be an org admin or have the runners and runner groups fine-grained
permission`) and the feature does not exist, so the organization path is closed before
any token-scope question comes up.

Both endpoints require `runner_group_id`. Omitting it on the **repository** endpoint
returns `422` with `Invalid input: object is missing required key: runner_group_id`.
The repository default group is always id `1`. This is easy to miss because the field
reads as an organization concept.

## Labels: a JIT config replaces, it does not extend

The defect that costs the most time, because everything looks healthy.

Registering with `labels: ["homelab"]` produces a runner whose label set is exactly
`["homelab"]`. There is no implicit `self-hosted` label.

The result: `GET /repos/{owner}/{repo}/actions/runners` shows the runner
`status: online`, `busy: false`. The workflow is valid. Every job queues forever.
Nothing in the UI names the cause.

Always send `self-hosted` explicitly. After that change the same workflow started within
30 seconds.

## Ephemerality

- The JIT config is delivered through `ACTIONS_RUNNER_INPUT_JITCONFIG`, which the runner
  maps to `--jitconfig`. It is single-use.
  See `CommandSettings` in [actions/runner](https://github.com/actions/runner).
- A JIT config **expires after one hour**. A loop that mints one per cycle shows a new
  idle runner in the repository roughly hourly. That is expected, not a leak.
- Delete the env file after `docker create`, because the file is read at create time.
  `--env-file` is not re-read at start.
- On a completed job the API reports `runner_name: null`, since the runner no longer
  exists. Not a failure signal.
- Leave runner auto-update on. GitHub enforces a minimum runner version and requires
  installing each new release within 30 days.

## The cycle must be bounded

`docker start -a` blocks until the container exits. A runner that loses its broker
session retries internally and **never exits**, so an unbounded `docker start -a` stops
the loop from minting the next runner.

Run each cycle under a timeout:

```bash
timeout --signal=TERM --kill-after=30 900 docker start -a "$CYCLE_CID"
```

## Process supervision: avoid the subshell trap

Running each cycle as `if (run_once); then` — a subshell with its own
`trap cleanup_cycle EXIT` — leaves an orphan on `systemctl restart`. The parent receives
SIGTERM while the subshell is inside `docker start -a`; the subshell is re-parented to
init and keeps running:

```
3412     1  bash /usr/local/sbin/gh-runner-loop.sh   <- new MainPID
3625  3412  bash /usr/local/sbin/gh-runner-loop.sh   <- orphan, still minting JIT
```

Two JIT configs consumed per cycle, and a second runner registered with no `self-hosted`
label. Call `run_once` directly and clean up explicitly at the end of every branch.

A related trap: `local` variables inside `run_once` are destroyed before the EXIT trap of
a subshell fires, so `set -u` aborts the trap with `envfile: unbound variable` and every
cycle fails *after* doing its work.

## The runner image is not a toolbox

`ghcr.io/actions/actions-runner` is Debian plus the runner binary — no Python, no Node,
no Rust, no C compiler. A workflow that passes on `ubuntu-latest` because those tools are
preinstalled fails here. Two consequences seen in practice:

- A job that shells out to `cc` fails with `linker cc not found`. Install
  `build-essential` (or the equivalent) in the job.
- `rustup` and `mise` extract installers into `/tmp` and execute them, so `/tmp` must be
  mounted `exec`. On a `noexec` tmpfs `rustup-init` fails with `Permission denied`, which
  reads as a broken toolchain.

## Running scripts before or after a job

Scripts can automatically run on a self-hosted runner, directly before or after a job.

Read more: [Github Docs](https://docs.github.com/en/actions/hosting-your-own-runners/running-scripts-before-or-after-a-job)

#### Set up pre- and post-job scripts

Search for the `.env` file in the self-hosted executor application directory
`$HOME/actions-runner`,

```shell
ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/path/to/script.sh
```

## Upstream

- Self-hosted runners: https://docs.github.com/en/actions/hosting-your-own-runners
- JIT config API: https://docs.github.com/en/rest/actions/self-hosted-runners
- Runner groups: https://docs.github.com/en/rest/actions/self-hosted-runner-groups
- actions/runner: https://github.com/actions/runner
- Official runner image: https://github.com/actions/runner/pkgs/container/actions-runner
