# Check Multiple Packages for Installability

Batch validation of package installability across CRAN, Bioconductor,
and GitHub.

## Usage

``` r
check_installable(
  packages,
  check_cran = TRUE,
  check_bioc = TRUE,
  check_github = TRUE,
  progress = TRUE
)
```

## Arguments

- packages:

  Character vector. Package names to check.

- check_cran:

  Logical. Check CRAN. Default: TRUE.

- check_bioc:

  Logical. Check Bioconductor. Default: TRUE.

- check_github:

  Logical. Check GitHub. Default: TRUE.

- progress:

  Logical. Show progress. Default: TRUE.

## Value

A data frame with columns: package, installable, source

## Examples

``` r
if (FALSE) { # \dontrun{
check_installable(c("dplyr", "ggplot2", "NonExistent"))
} # }
```
