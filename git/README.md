# git

git - the stupid content tracker

## Table of Contents

- [git status](#git-status)
- [git branch](#git-branch)
- [git config](#git-config)
- [git checkout](#git-checkout)
- [git add](#git-add)
- [git rm](#git-rm)
- [git remote](#git-remote)
- [git log](#git-log)
- [git commit](#git-commit)
- [git diff](#git-diff)

### git status

Show the working tree status:
```shell
git status
```
Show the branch and tracking info in short-format:
```shell
git status -bs
```

### git branch

Show the current branch context:
```shell
git branch
```

List both remote-tracking and local branches:
```shell
git branch -a
```

List branch names:
```shell
git branch -l
```

Show only the current branch name:
```shell
git branch --show-current
```

#### Create a branch

To create a new branch and switch to it at same time, run the following command:
```shell
git checkout -b <branch-name>
```

Once the new branch is created, push it:
```shell
git push -u origin <branch-name>
```

#### Delete a branch

Delete a branch remotely:
```shell
git push -d origin <branch-name>
```

Once the branch has been deleted remotely, delete it locally:
```shell
git branch -D <branch-name>
```

### git checkout

Switch branch:
```shell
git checkout <branch-name>
```

Switch branch even if the index or the working tree differs from `HEAD`:
```shell
git checkout -f <branch-name>
```

Switch to previous branch:
```shell
git checkout -
```

### git config

List your global `git` configuration:
```shell
git config --global -l
```

List your local `git` configuration:
```shell
git config --local -l
```

#### global config repositories

Setting your Git username for every repository on your computer:
```shell
git config --global user.name "Your Name"
```
Confirm that you have set the Git username correctly `global config`:
```shell
git config --global user.name
```

Setting your email address for every repository on your computer:
```shell
git config --global user.email "email@example.com"
```

Confirm that you have set the email address correctly in Git `global config`:
```shell
git config --global user.email
```

Edit global repository config:
```shell
git config --global --edit
```

#### single config repository

Setting your Git username for a single repository:
```shell
git config user.name "Your Name"
```

Confirm that you have set the Git username correctly `single repository`:
```shell
git config user.name
```

Setting your email address for a single repository:
```shell
git config user.email "email@example.com"
```

Confirm that you have set the Git username correctly `single repository`:
```shell
git config user.email
```

Edit single repository config:
```shell
git config --edit
```

### git add

Add files:
```shell
git add .
```

Add files recursively:
```shell
git add -A
```

### git rm

Remove files from the working tree and from the index:
```shell
git rm -f <file>
```

Remove a directory from the working tree:
```shell
git rm -r <directory>
```

### git remote

Show locations:
```shell
git remote -v
```

Update location:
```shell
git remote set-url origin <new-github-repo-url>
```

Deletes all stale remote-tracking branches:
```shell
git remote prune origin
```

Show information about the remote:
```shell
git remote show origin
```

### git log

Show commit logs with pretty output:
```shell
git log --oneline
```

Get the hash of the last commit:
```shell
git log -1 --format="%H"
```

### git commit

#### Empty commit

Empty commit to trigger CI via github actions:
```shell
git commit --allow-empty -m "actions: trigger CI"
```

Push empty commit to activate CI:
```
git push
```

#### Undo a commit

If you have not pushed your changes to remote, run follow steps:

List most recent commits with nice formatting to identify unwanted commits:
```shell
git log --oneline
```

Once identified, run this command to undo this commit:
```shell
git reset HEAD~1
```

### git diff

// description:
```shell
git diff
```

// description:
```shell
git diff --color-words
```

### Related links

- [Git: avoid reset --hard, use reset --keep instead](https://adamj.eu/tech/2024/09/02/git-avoid-reset-hard-use-keep/)
- [Git: generate statistics with shortlog](https://adamj.eu/tech/2024/09/03/git-quick-stats-shortlog/)
- [Git: count commits with rev-list](https://adamj.eu/tech/2024/11/20/git-count-commits-rev-list/)
- [Git into Open Source](https://www.git-in.to/)
- [Beej's Guide to Git](https://beej.us/guide/bggit/)
- [Oh My Git - An open source game about learning Git!](https://ohmygit.org/)
- [Modern Git Commands and Features You Should Be Using](https://martinheinz.dev/blog/109)
