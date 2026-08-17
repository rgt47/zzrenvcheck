# Standard Directories to Scan

Default directories scanned in standard (non-strict) mode. Excludes "."
(the project root) because scanning is recursive
([`extract_code_packages()`](https://rgt47.github.io/zzrenvcheck/reference/extract_code_packages.md)
passes `recursive = TRUE`), so including "." would recurse into `tests/`
and `vignettes/` regardless of `strict`, defeating the standard/strict
distinction, and would double-count files already reached via "R".

## Usage

``` r
STANDARD_DIRS
```
