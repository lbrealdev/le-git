# Github Actions - Self-hosted runners

Initiatives and solutions for self-hosted runners from Github Actions.

### Running scripts before or after a job

Scripts can automatically run on a self-hosted runner, directly before or after a job.

Read more: [Github Docs](https://docs.github.com/en/actions/hosting-your-own-runners/running-scripts-before-or-after-a-job)

#### Set up pre- and post-job scripts

Search for the `.env` file in the self-hosted executor application directory `$HOME/actions-runner`, 

```shell
ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/path/to/script.sh
```