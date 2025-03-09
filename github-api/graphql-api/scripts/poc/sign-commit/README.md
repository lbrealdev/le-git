# GraphQL API sign commit

### Usage

Export GITHUB_TOKEN:
```shell
export GITHUB_AUTH_TOKEN="<github-token>"
```

Upload files using **GitHub graphql API**:
```shell
./sign-commit-upload.sh -r "owner/repository" -u empty-dir/
```

Delete files using **GitHub graphql API**:
```shell
./sign-commit-delete.sh -r "owner/repository" -d empty-dir/
```

### Outputs

Upload json output:
```json
{
  "data": {
    "createCommitOnBranch": {
      "commit": {
        "url": "https://github.com/owner/repository/commit/a65eb245c54c730b6AA090a5fc387000f88db131",
        "additions": 2423,
        "changedFilesIfAvailable": 4,
        "committedDate": "2024-07-17T22:22:48Z",
        "authoredDate": "2024-07-17T22:22:48Z",
        "deletions": 0,
        "committer": {
          "name": "GitHub",
          "date": "2024-07-18T00:22:48+02:00",
          "email": "noreply@github.com"
        },
        "oid": "a65eb245c8ec7d10234890a5fc3865431233b131",
        "signature": {
          "isValid": true,
          "signer": {
            "login": "web-flow"
          }
        }
      }
    }
  }
}
```

Delete json output:
```json
{
  "data": {
    "createCommitOnBranch": {
      "commit": {
        "url": "https://github.com/owner/repository/commit/67877110e0e123c2e67ed0a10aa590b2993466bd",
        "additions": 0,
        "changedFilesIfAvailable": 4,
        "committedDate": "2024-07-17T18:08:04Z",
        "authoredDate": "2024-07-17T18:08:04Z",
        "deletions": 2423,
        "committer": {
          "name": "GitHub",
          "date": "2024-07-17T20:08:04+02:00",
          "email": "noreply@github.com"
        },
        "oid": "67877110e0e111c2e67ed0a3dd4590b2549366bd",
        "signature": {
          "isValid": true,
          "signer": {
            "login": "web-flow"
          }
        }
      }
    }
  }
}
```
