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
  versions = TRUE,
  fresh = FALSE,
  error_on_fail = FALSE,
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

- transitive:

  Logical. If TRUE, also resolve and add transitive dependencies when
  fixing renv.lock. Default: FALSE.

- versions:

  Logical. If TRUE, check that package versions are consistent across
  DESCRIPTION constraints, renv.lock, and code install pins. Default:
  TRUE.

- fresh:

  Logical. If TRUE, rebuild renv.lock from a clean code scan,
  re-resolving every package and its transitive dependencies to the
  current repository versions instead of preserving existing pins, and
  pruning packages no longer used by code. A deliberate version refresh
  (it can pull breaking updates); ordinary `auto_fix` keeps pinned
  versions. Routes through
  [`sync_packages`](https://rgt47.github.io/zzrenvcheck/reference/sync_packages.md).
  Default: FALSE.

- error_on_fail:

  Logical. If TRUE, raise an error (rather than returning) when
  validation fails, so a non-interactive `Rscript` run exits with a
  non-zero status. The signalled condition has class
  `zzrenvcheck_validation_failure` and carries the result list in its
  `result` field. Default: FALSE.

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
