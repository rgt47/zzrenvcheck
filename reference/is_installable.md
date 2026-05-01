# Check if Package is Installable

Validates whether a package can be installed from CRAN, Bioconductor, or
GitHub. Returns information about the source if found.

## Usage

``` r
is_installable(
  package,
  check_cran = TRUE,
  check_bioc = TRUE,
  check_github = TRUE
)
```

## Arguments

- package:

  Character. Package name or "owner/repo" for GitHub.

- check_cran:

  Logical. Check CRAN. Default: TRUE.

- check_bioc:

  Logical. Check Bioconductor. Default: TRUE.

- check_github:

  Logical. Check GitHub. Default: TRUE.

## Value

A list with:

- installable: Logical indicating if package can be installed

- source: Character indicating source ("CRAN", "Bioconductor", "GitHub",
  or NA)

- package: The package name

## Examples

``` r
if (FALSE) { # \dontrun{
is_installable("dplyr")
# Returns: list(installable = TRUE, source = "CRAN", package = "dplyr")

is_installable("NonExistentPkg123")
# Returns: list(installable = FALSE, source = NA, package = "NonExistentPkg123")
} # }
```
