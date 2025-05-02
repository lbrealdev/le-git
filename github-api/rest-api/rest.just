# GitHub REST API scripts

owner := 'to-ge-da'
repo := 'test-create-repo-with-just'

set working-directory := 'scripts'

@create-branch-rule branch:
  ./rest-branch-rule.sh create {{ owner }}/{{ repo }} {{ branch }}

@update-repo source target *private:
  ./rest-update-repo.sh {{ owner }}/{{ source }} {{ target }} {{ private }}
