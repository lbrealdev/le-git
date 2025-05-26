# Git: Tricks and Tips

Prune origin and delete branch locally:
```shell
git remote prune origin | grep 'pruned' | cut -d'/' -f2 | xargs git branch -D 2> /dev/null
```

Show last commit changes:
```shell
git show $(git log -1 --format="%H")
```
