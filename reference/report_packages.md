# Report Package Status

Reports the current status of package dependencies without making
changes. Provides a clear summary of packages in code, DESCRIPTION, and
renv.lock.

## Usage

``` r
report_packages(strict = FALSE, path = ".")
```

## Arguments

- strict:

  Logical. If TRUE, scans tests/ and vignettes/ directories. Default:
  TRUE.

- path:

  Character. Path to project root. Default: current directory.

## Value

A data frame with package status

## Examples

``` r
if (FALSE) { # \dontrun{
# View package status
status <- report_packages()
print(status)
} # }
```
