# GitHub REST API scripts

owner := 'to-ge-da'

set working-directory := 'scripts'

@create-branch-rule target branch:
  ./rest-branch-rule.sh create {{ owner }}/{{ target }} {{ branch }}

@delete-branch-rule target branch:
  ./rest-branch-rule.sh delete {{ owner }}/{{ target }} {{ branch }}

@update-repo source target *private:
  ./rest-update-repo.sh {{ owner }}/{{ source }} {{ target }} {{ private }}
