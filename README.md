# le-git

This document contains **le-git** `(legit)` that means "Let's Explain Git and Github". This is my own public documentation about git and github where I make random updates to one topic or another about the two tools

### git status

Show the working tree status:
```
git status
```
Show the branch and tracking info in short-format:
```
git status -bs
```

### git branch

Show the current branch context:
```
git branch
```

List both remote-tracking and local branches:
```
git branch -a
```

List branch names:
```
git branch -l
```

Create a new branch:
```
git branch -m <new_branch>
```

Change branch:
```
git checkout <other_branch>
```

Force change branch:
```
git checkout -f <other_branch>
```


### git config

List your global `git` configuration:
```
git config --global -l
```

List your local `git` configuration:
```
git config --local -l
```

#### global config repositories

Setting your Git username for every repository on your computer:
```
git config --global user.name "Your Name"
```
Confirm that you have set the Git username correctly `global config`:
```
git config --global user.name
```

Setting your email address for every repository on your computer:
```
git config --global user.email "email@example.com"
```

Confirm that you have set the email address correctly in Git `global config`:
```
git config --global user.email
```

Edit global repository config:
```
git config --global --edit
```

#### single config repository

Setting your Git username for a single repository:
```
git config user.name "Your Name"
```

Confirm that you have set the Git username correctly `single repository`:
```
git config user.name
```

Setting your email address for a single repository:
```
git config user.email "email@example.com"
```

Confirm that you have set the Git username correctly `single repository`:
```
git config user.email
```

Edit single repository config:
```
git config --edit
```

### git rm

Remove files from the working tree and from the index:
```
git rm -f <file>
```

Remove a directory from the working tree:
```
git rm -r <dir>
```
