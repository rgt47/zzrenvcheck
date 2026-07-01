# Extract Version-Pinned Package Installs from Code

Scans source files for package installation calls that pin an exact
version, recording the package name together with the pinned version.
Recognised forms are documented in `CODE_PIN_PATTERNS`: pak and renv
`@`-syntax (`pak::pak('dplyr@1.1.0')`) and the `version=` argument of
`remotes`/`devtools` `install_version()`.

## Usage

``` r
extract_code_package_versions(
  dirs = c("R", "scripts", "analysis"),
  path = ".",
  skip_comments = TRUE
)
```

## Arguments

- dirs:

  Character vector of directory paths to scan.

- path:

  Character. Path to project root. Default: current directory.

- skip_comments:

  Logical. Skip commented lines. Default: TRUE.

## Value

Data frame with columns `package` and `version` (character). One row per
pinned mention; the same package may appear more than once if pinned to
differing versions across files.

## Details

Only explicitly pinned installs are returned; ordinary
[`library()`](https://rdrr.io/r/base/library.html)/`::` references carry
no version and are ignored here (they are handled by
[`extract_code_packages()`](https://rgt47.github.io/zzrenvcheck/reference/extract_code_packages.md)).
Package names are filtered through
[`clean_package_names()`](https://rgt47.github.io/zzrenvcheck/reference/clean_package_names.md)
so the same false-positive rules apply.

## Examples

``` r
if (FALSE) { # \dontrun{
pins <- extract_code_package_versions(dirs = c("R", "analysis"))
} # }
```
