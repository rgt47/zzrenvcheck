# Parse renv.lock Package Versions

Extracts package names and their locked exact versions from an renv.lock
file. Unlike
[`parse_renv_lock()`](https://rgt47.github.io/zzrenvcheck/reference/parse_renv_lock.md),
which returns names only, this retains the `Version` recorded for each
package so that cross-document version synchronisation can be validated.

## Usage

``` r
parse_renv_lock_versions(path = ".")
```

## Arguments

- path:

  Character. Path to project root containing renv.lock. Default: current
  directory.

## Value

Data frame with columns `package` and `version` (character). Packages
without a recorded version yield `NA_character_`. Returns a zero-row
data frame when renv.lock is absent or empty.
