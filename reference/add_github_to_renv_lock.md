# Add GitHub Package to renv.lock

Adds a GitHub-hosted package entry to renv.lock with proper remote
metadata (RemoteType, RemoteHost, RemoteUsername, RemoteRepo,
RemoteRef). Fetches version from the repository DESCRIPTION file when
possible.

## Usage

``` r
add_github_to_renv_lock(package, remote, path = ".")
```

## Arguments

- package:

  Character. Package name.

- remote:

  Character. GitHub remote in "owner/repo" or "owner/repo@ref" format.

- path:

  Character. Path to project root.

## Value

Logical indicating success
