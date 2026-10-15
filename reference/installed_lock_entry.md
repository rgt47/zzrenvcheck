# Build a renv.lock Entry from an Installed Package

Reads the DESCRIPTION of the copy of `package` found on `lib.loc` and
returns the lockfile entry that records the version actually installed,
with its source: GitHub remote fields when the package was installed
from GitHub, otherwise the `Repository` field (for example `CRAN` or
`RSPM`).

## Usage

``` r
installed_lock_entry(package, lib.loc = NULL)
```

## Arguments

- package:

  Character. Package name.

- lib.loc:

  Character vector of library paths, or NULL for
  [`.libPaths()`](https://rdrr.io/r/base/libPaths.html).

## Value

A named list suitable for `renv.lock`'s `Packages` section, or NULL when
the package is not installed.
