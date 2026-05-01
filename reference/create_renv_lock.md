# Create Empty renv.lock

Creates a new renv.lock file with R version and repository settings.

## Usage

``` r
create_renv_lock(
  r_version = NULL,
  cran_url = "https://cloud.r-project.org",
  path = "."
)
```

## Arguments

- r_version:

  Character. R version. Default: current R version.

- cran_url:

  Character. CRAN repository URL. Default:
  "https://cloud.r-project.org".

- path:

  Character. Path to project root. Default: current directory.

## Value

Logical indicating success

## Examples

``` r
if (FALSE) { # \dontrun{
# Create with current R version
create_renv_lock()

# Create with specific R version
create_renv_lock(r_version = "4.4.0")
} # }
```
