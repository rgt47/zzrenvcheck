# Get Current Package Name

Extracts package name from DESCRIPTION file to avoid self-reference.

## Usage

``` r
get_current_package_name(path = ".")
```

## Arguments

- path:

  Character. Path to project root.

## Value

Character. Package name, or NULL if not found.
