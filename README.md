# le-git

<!-- TOC -->

- [graphql-api](https://github.com/lbrealdev/le-git/tree/master/graphql-api)
- [github-actions](https://github.com/lbrealdev/le-git/tree/master/graphql-api)

This document contains **le-git** `(legit)` that means "Let's Explain Git and Github". This is my own public documentation about git and github where I make random updates to one topic or another about the two tools

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

Change branch:
```shell
git checkout <other_branch>
```

Force change branch:
```shell
git checkout -f <other_branch>
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

    // Add content

### git rm

Remove files from the working tree and from the index:
```shell
git rm -f <file>
```

Remove a directory from the working tree:
```shell
git rm -r <dir>
```

### git remote

Show the location configured:
```shell
git remote -v
```

Update location:
```shell
git remote set-url origin <new-github-repo-url>
```

### git log

Show commit logs with pretty output:
```shell
git log --oneline
``` 

### git commit

#### Empty commit
Empty commit to trigger CI via github actions:
```
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

