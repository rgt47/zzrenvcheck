# Check Package Dependencies

Validates that all R packages used in code are properly declared in
DESCRIPTION and locked in renv.lock for reproducibility.

## Usage

``` r
check_packages(
  strict = TRUE,
  auto_fix = FALSE,
  cleanup = FALSE,
  verbose = TRUE,
  validate_sources = auto_fix,
  transitive = FALSE,
  path = "."
)
```

## Arguments

- strict:

  Logical. If TRUE, scans tests/ and vignettes/ directories. Default:
  TRUE.

- auto_fix:

  Logical. If TRUE, automatically adds missing packages. Default: FALSE.

- cleanup:

  Logical. If TRUE, syncs to code (adds missing, removes unused).
  Equivalent to calling sync_packages(). Default: FALSE.

- verbose:

  Logical. If TRUE, lists all issues found. Default: TRUE.

- validate_sources:

  Logical. If TRUE, checks if packages are installable from
  CRAN/Bioconductor/GitHub before adding. Default: TRUE when auto_fix.

- path:

  Character. Path to project root. Default: current directory.

## Value

Invisibly returns a list with validation results

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic validation
check_packages()

# Auto-fix missing packages
check_packages(auto_fix = TRUE)

# Cleanup mode: sync to code (remove unused, add missing)
check_packages(cleanup = TRUE)

# Non-strict mode (skip tests and vignettes)
check_packages(strict = FALSE)
} # }
```
