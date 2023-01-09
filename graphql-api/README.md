# GraphQL API

#### Use

To use graphQL API for github, first you need to have installed `gh cli`:
```shell
gh version
```

Follow the instructions from that repository to install the [Github CLI](https://github.com/cli/cli).

Once installed, authenticate against github, using your PAT (Personal Access Token), run the following command:
```shell
gh auth login --with-token < token.txt
```
>
>Create your token in your github configuration panel, then save it to a file, there are other ways to do it, at the end the --with-token argument reads a file where this token is
>
>

Make sure you are connected via gh cli correctly, run:
```shell
gh auth status
```

Modify line 4 of the script in the arguments of the repository graphql object with your github owner and the name of the repository, once done execute:

```grapgql
{
    repository(owner:"owner", name:"repository") {
        // ...
    }
}
```

```shell
./branch-protection-rule.sh
```

#### Notes

The `restrictsPushes` input field only works for organization repositories.


### Queries

Queries are structured like this:

```graphql
query {
  JSON-OBJECT-TO-RETURN
}
```


### Mutations

Mutations are structured like this:

```graphql
mutation {
  MUTATION-NAME(input: {MUTATION-NAME-INPUT!}) {
    MUTATION-NAME-PAYLOAD
  }
}
```

Source: [Forming calls with GraphQL](https://docs.github.com/en/graphql/guides/forming-calls-with-graphql)



[Github GraphQL API](https://docs.github.com/en/graphql/reference)