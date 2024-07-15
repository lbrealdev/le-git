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

### Source

- [Disabling OAuth app access restrictions for your organization](https://docs.github.com/en/organizations/managing-oauth-access-to-your-organizations-data/disabling-oauth-app-access-restrictions-for-your-organization)
- [Migrating GraphQL global node IDs](https://docs.github.com/en/graphql/guides/migrating-graphql-global-node-ids)