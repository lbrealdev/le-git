# git
This document explains how to use everyday git commands







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
git branch <branch_name>
```

Change branch:
```
git checkout <branch_name>
```

Force change branch:
```
git checkout -f <branch_name>
```


### git config

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
git rm -f $file
```

Remove a directory from the working tree:
```
git rm -r $dir
```
