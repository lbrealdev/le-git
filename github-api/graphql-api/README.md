# GitHub GraphQL API

To use graphQL API for github, first you need to have installed `gh cli`:
```shell
gh version
```

Follow the instructions from that repository to install the [Github CLI](https://github.com/cli/cli).

Once installed, authenticate against github, run the following command:
```shell
echo "$YOUR_GITHUB_PAT" | gh auth login --with-token
```

Make sure you are connected via gh cli correctly, run:
```shell
gh auth status
```

Run this script to get authenticated user information:
```shell
./graphql-user-info.sh
```

### Queries

Queries are structured like this:

```graphql
query {
  JSON-OBJECT-TO-RETURN
}
```

### Notes

The `restrictsPushes` input field only works for organization repositories.

### Mutations

Mutations are structured like this:

```graphql
mutation {
  MUTATION-NAME(input: {MUTATION-NAME-INPUT!}) {
    MUTATION-NAME-PAYLOAD
  }
}
```

## Related links

- [GitHub GraphQL API documentation](https://docs.github.com/en/graphql)
- [Forming calls with GraphQL](https://docs.github.com/en/graphql/guides/forming-calls-with-graphql)
- [Github GraphQL API reference](https://docs.github.com/en/graphql/reference)
- [Github GraphQL Explorer](https://docs.github.com/en/graphql/overview/explorer)
