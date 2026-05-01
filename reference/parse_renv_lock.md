# Parse renv.lock Packages

Extracts package names from an renv.lock file.

## Usage

``` r
parse_renv_lock(path = ".")
```

## Arguments

- path:

  Character. Path to project root containing renv.lock. Default: current
  directory.

## Value

Character vector of package names (sorted, deduplicated)

## Examples

``` r
if (FALSE) { # \dontrun{
locked_packages <- parse_renv_lock()
} # }
```
