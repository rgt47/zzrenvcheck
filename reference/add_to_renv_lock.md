# Add Package to renv.lock

Adds a package entry to renv.lock by querying CRAN API.

## Usage

``` r
add_to_renv_lock(package, version = NULL, path = ".")
```

## Arguments

- package:

  Character. Package name.

- version:

  Character. Package version. If NULL, fetches from CRAN.

- path:

  Character. Path to project root.

## Value

Logical indicating success
