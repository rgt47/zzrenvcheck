# Clean Unused Packages from DESCRIPTION

Removes packages from DESCRIPTION Imports that are not used in code.
This helps keep DESCRIPTION aligned with actual dependencies.

## Usage

``` r
clean_description(strict = TRUE, path = ".")
```

## Arguments

- strict:

  Logical. If TRUE, scans tests/ and vignettes/ directories. Default:
  TRUE.

- path:

  Character. Path to project root. Default: current directory.

## Value

Invisibly returns character vector of removed packages

## Examples

``` r
if (FALSE) { # \dontrun{
# Remove unused packages
clean_description()

# Strict mode (check all directories)
clean_description(strict = TRUE)
} # }
```
