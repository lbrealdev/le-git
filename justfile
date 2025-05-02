#import 'github-api/graphql-api/graphql.just'

mod gql 'github-api/graphql-api/graphql.just'
mod rest 'github-api/rest-api/rest.just'

@setup:
  pre-commit install
