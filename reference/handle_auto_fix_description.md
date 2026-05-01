# Handle Auto-Fix for DESCRIPTION

Automatically adds missing packages to DESCRIPTION Imports.

## Usage

``` r
handle_auto_fix_description(packages, path = ".")
```

## Arguments

- packages:

  Character vector of package names to add.

- path:

  Character. Path to project root.

## Value

Character vector of packages that failed to add
