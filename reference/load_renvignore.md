# Read .renvignore Patterns

Reads the project's `.renvignore`, returning its non-empty, non-comment
lines as patterns. Shared with renv so a single file governs which
sources are excluded from dependency scanning.

## Usage

``` r
load_renvignore(path)
```

## Arguments

- path:

  Character. Project root.

## Value

Character vector of patterns (possibly empty).
