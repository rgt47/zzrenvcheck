# Parse Structural DESCRIPTION Dependencies

Returns packages declared in `LinkingTo` or `Depends`. These are used
structurally, via compiled linkage (`LinkingTo`, e.g. Rcpp) or
attachment (`Depends`), rather than through
[`library()`](https://rdrr.io/r/base/library.html) or `::` in R source,
so the code scanner never sees them. They must not be reported as unused
or removed during sync/auto-fix. The base pseudo-package `R` (from a
`Depends: R (>= x)` constraint) is excluded.

## Usage

``` r
parse_description_structural(path = ".")
```

## Arguments

- path:

  Character. Path to project root.

## Value

Character vector of package names (sorted, deduplicated).
