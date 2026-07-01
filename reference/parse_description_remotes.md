# Parse Version-Pinned DESCRIPTION Remotes

Extracts package version pins from the `Remotes:` field of a DESCRIPTION
file. A remote reference is a git ref, so only version-like refs are
returned: a leading `v` is stripped and the remainder must begin with a
digit (e.g. `owner/repo@v1.1.0` or `owner/repo@1.1.0`). Branch names,
tags such as `devel`, and commit SHAs are not comparable to an
`renv.lock` version and are skipped. Type prefixes (`github::`,
`gitlab::`, ...) are removed; the package name is taken from the final
path segment of the repository.

## Usage

``` r
parse_description_remotes(path = ".")
```

## Arguments

- path:

  Character. Path to project root.

## Value

Data frame with columns `package` and `version` (character); zero rows
when no version-like remotes are declared.
