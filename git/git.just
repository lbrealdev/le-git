# Git helper scripts

set working-directory := 'scripts'

# Report credential.helper at each Git config scope (read-only)
@credential-audit *args:
  ./git-credential-helper-audit.sh {{ args }}

# Compare current branch to origin/HEAD (main vs master)
@default-branch *args:
  ./git-default-branch-check.sh {{ args }}
