# git - the stupid content tracker

### Git tricks

prune origin and delete branch locally:
```shell
git remote prune origin | grep 'pruned' | cut -d'/' -f2 | xargs git branch -D 2> /dev/null
```