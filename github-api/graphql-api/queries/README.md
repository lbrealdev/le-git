# GitHub GraphQL API queries

### Usage

Query:
```graphql
query GetReposFromOrg($owner: String!) {
  organization(login: $owner) {
    id
    name
    login
    description
    resourcePath
    email
    createdAt
    repositories(first: 100, after: null) {
      nodes {
        id
        name
      }
    }
  }
}
```

Variables:
```graphql
{
  "owner": "<login>"
}
```
