# Resolve Transitive Package Dependencies

Resolves the full transitive dependency closure for a set of packages
using the CRAN package database. Returns all packages (direct and
transitive) with their current CRAN versions.

## Usage

``` r
resolve_transitive_deps(
  packages,
  db = NULL,
  which = c("Imports", "Depends", "LinkingTo")
)
```

## Arguments

- packages:

  Character vector of package names.

- db:

  Matrix. Result of
  [`available.packages()`](https://rdrr.io/r/utils/available.packages.html).
  If NULL, fetched from CRAN (one network round-trip).

- which:

  Character vector. Dependency types to follow. Default:
  `c("Imports", "Depends", "LinkingTo")`. "Suggests" is excluded by
  default as suggested packages are optional.

## Value

Named character vector: names are package names, values are versions.
Only includes packages available on CRAN.

## Details

Non-CRAN packages (GitHub, Bioconductor) are skipped with a warning;
their transitive CRAN dependencies are still resolved where possible.

## Examples

``` r
if (FALSE) { # \dontrun{
# Resolve all transitive deps of ggplot2
resolve_transitive_deps("ggplot2")

# Reuse a pre-fetched database for multiple calls
db <- available.packages()
resolve_transitive_deps(c("dplyr", "tidyr"), db = db)
} # }
```
