# Handle Auto-Fix for renv.lock

Automatically adds missing packages to renv.lock via CRAN API. Does not
validate package sources - use handle_auto_fix_lock_with_validation for
source checking.

## Usage

``` r
handle_auto_fix_lock(packages, path = ".")
```

## Arguments

- packages:

  Character vector of package names to add.

- path:

  Character. Path to project root.

## Value

Character vector of packages that failed to add
