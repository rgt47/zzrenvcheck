# Sync Packages to Code

Synchronizes DESCRIPTION and renv.lock to match packages used in code.
Code is treated as the source of truth. Adds missing packages and
removes unused packages.

## Usage

``` r
sync_packages(
  strict = TRUE,
  path = ".",
  verbose = FALSE,
  dry_run = FALSE,
  transitive = FALSE
)
```

## Arguments

- strict:

  Logical. If TRUE, scans tests/ and vignettes/. Default: TRUE.

- path:

  Character. Path to project root. Default: current directory.

- verbose:

  Logical. Show detailed output. Default: FALSE.

- dry_run:

  Logical. If TRUE, only report changes without making them. Default:
  FALSE.

- transitive:

  Logical. If TRUE, also resolve and add transitive dependencies to
  renv.lock. Default: FALSE.

## Value

Invisibly returns a list with changes made

## Details

This function treats code as the single source of truth:

- Packages used in code but not in DESCRIPTION → added to DESCRIPTION

- Packages in DESCRIPTION but not in code → removed from DESCRIPTION

- Packages used in code but not in renv.lock → added to renv.lock

- Packages in renv.lock but not in code → removed from renv.lock

The "renv" package is always protected and never removed.

## Examples

``` r
if (FALSE) { # \dontrun{
# Sync packages (code is source of truth)
sync_packages()

# Preview changes without applying
sync_packages(dry_run = TRUE)

# Sync with verbose output
sync_packages(verbose = TRUE)
} # }
```
