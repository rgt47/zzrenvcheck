# Parse DESCRIPTION Imports and Suggests

Extracts package names from both Imports and Suggests fields, returning
the union. This matches the validation.sh behavior which treats both
fields as "declared" packages.

## Usage

``` r
parse_description_declared(path = ".")
```

## Arguments

- path:

  Character. Path to project root.

## Value

Character vector of package names (sorted, deduplicated)
