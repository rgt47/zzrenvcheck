# Extract Package References from R Code

Scans R source files for package references including library(),
require(), namespace calls (pkg::function), and roxygen2 imports.

## Usage

``` r
extract_code_packages(
  dirs = c("R", "scripts", "analysis"),
  path = ".",
  skip_comments = TRUE
)
```

## Arguments

- dirs:

  Character vector of directory paths to scan.

- path:

  Character. Path to project root. Default: current directory.

- skip_comments:

  Logical. Skip commented lines. Default: TRUE.

## Value

Character vector of package names (may contain duplicates)

## Details

This function extracts packages from:

- library(pkg)

- require(pkg)

- pkg::function()

- @importFrom pkg function

- @import pkg

## Examples

``` r
if (FALSE) { # \dontrun{
# Extract from R directory
packages <- extract_code_packages(dirs = "R")

# Extract from multiple directories
packages <- extract_code_packages(dirs = c("R", "scripts", "tests"))
} # }
```
