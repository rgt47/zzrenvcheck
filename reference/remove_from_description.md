# Remove Packages from DESCRIPTION

Removes specified packages from the Imports field in DESCRIPTION.

## Usage

``` r
remove_from_description(packages, path = ".")
```

## Arguments

- packages:

  Character vector. Package names to remove.

- path:

  Character. Path to project root.

## Value

Character vector of successfully removed packages
