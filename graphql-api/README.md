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

