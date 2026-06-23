# Fix Packages (Convenience Wrapper)

Automatically adds missing packages to DESCRIPTION and renv.lock. This
is a convenience wrapper around check_packages(auto_fix = TRUE).

## Usage

``` r
fix_packages(strict = TRUE, transitive = FALSE, path = ".")
```

## Arguments

- strict:

  Logical. If TRUE, scans tests/ and vignettes/ directories. Default:
  TRUE.

- transitive:

  Logical. If TRUE, also resolve and add transitive dependencies when
  fixing renv.lock. Default: FALSE.

- path:

  Character. Path to project root. Default: current directory.

## Value

Invisibly returns a list with packages that were added

## Examples

``` r
if (FALSE) { # \dontrun{
# Fix all missing packages
fix_packages()

# Fix with transitive dependency resolution
fix_packages(transitive = TRUE)

# Fix with non-strict mode
fix_packages(strict = FALSE)
} # }
```
