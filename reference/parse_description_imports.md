# Parse DESCRIPTION Imports

Extracts package names from the Imports field of a DESCRIPTION file.
Handles multi-line continuation and removes version constraints.

## Usage

``` r
parse_description_imports(path = ".")
```

## Arguments

- path:

  Character. Path to project root containing DESCRIPTION. Default:
  current directory.

## Value

Character vector of package names (sorted, deduplicated)

## Examples

``` r
if (FALSE) { # \dontrun{
imports <- parse_description_imports()
} # }
```
