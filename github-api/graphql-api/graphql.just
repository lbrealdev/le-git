# GitHub GraphQL API scripts

set working-directory := 'scripts'

@next-id user:
  ./graphql-user-next-id.sh {{ user }}
