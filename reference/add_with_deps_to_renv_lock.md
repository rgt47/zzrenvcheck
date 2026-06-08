# Add Packages to renv.lock with Transitive Dependencies

Resolves the full dependency closure for the given packages and adds all
of them (direct and transitive) to renv.lock. Existing entries are
overwritten with current CRAN versions.

## Usage

``` r
add_with_deps_to_renv_lock(packages, path = ".", db = NULL)
```

## Arguments

- packages:

  Character vector of package names.

- path:

  Character. Path to project root. Default: current directory.

- db:

  Matrix. Result of
  [`available.packages()`](https://rdrr.io/r/utils/available.packages.html).
  If NULL, fetched from CRAN. Pass a pre-fetched db to avoid redundant
  network calls when adding multiple package sets.

## Value

Invisible logical indicating success.

## Examples

``` r
if (FALSE) { # \dontrun{
add_with_deps_to_renv_lock(c("ggplot2", "dplyr"))
} # }
```
