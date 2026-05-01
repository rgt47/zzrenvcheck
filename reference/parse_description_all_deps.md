# Parse DESCRIPTION All Dependencies

Extracts all package dependencies (Imports, Suggests, Depends) from
DESCRIPTION.

## Usage

``` r
parse_description_all_deps(
  path = ".",
  types = c("Imports", "Suggests", "Depends")
)
```

## Arguments

- path:

  Character. Path to project root.

- types:

  Character vector. Dependency types to include. Default: c("Imports",
  "Suggests", "Depends").

## Value

Data frame with columns: package, type, version

## Examples

``` r
if (FALSE) { # \dontrun{
all_deps <- parse_description_all_deps()
} # }
```
