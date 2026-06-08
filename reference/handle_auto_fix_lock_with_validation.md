# Handle Auto-Fix for renv.lock with Source Validation

Validates packages against CRAN/Bioconductor/GitHub before adding.
Separates installable from non-installable packages.

## Usage

``` r
handle_auto_fix_lock_with_validation(
  packages,
  path,
  verbose,
  transitive = FALSE
)
```

## Arguments

- packages:

  Character vector of package names.

- path:

  Character. Path to project root.

- verbose:

  Logical. Show detailed output.

## Value

List with installable and non_installable character vectors
