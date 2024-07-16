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

### Tools

- [Data Fetcher - GraphQL to JSON Body Converter](https://datafetcher.com/graphql-json-body-converter)
- [Transform Tools - GraphQL to Introspection JSON](https://transform.tools/graphql-to-introspection-json)
- [JSON Lint - Format & Validate JSON](https://www.jsolint.com/)

### Important things in GitHub GraphQL API

- [createCommitOnBranch](https://docs.github.com/en/graphql/reference/mutations#createcommitonbranch)
- [Commit](https://docs.github.com/en/graphql/reference/objects#commit)
- [TreeEntry](https://docs.github.com/en/graphql/reference/objects#treeentry)
