# GitHub REST API scripts

owner := 'to-ge-da'

set working-directory := 'scripts'

# Create repository branch protection rules
@repo-branch-rule action target *branch:
  ./rest-branch-rule.sh {{ action }} {{ owner }}/{{ target }} {{ branch }}

# Update repository
@repo-update target name description private *homepage:
  ./rest-update-repo.sh {{ target }} {{ name }} {{ description }} {{ private }} {{ homepage }}

# Private recipe
@_update target *private:
  ./rest-update-repo.sh {{ target }} {{ private }}
