# Package-API Directories

Directories whose packages must be declared in DESCRIPTION. In a
research compendium, `analysis/` and `scripts/` hold analysis-only code
whose packages need only appear in `renv.lock`, not in DESCRIPTION. Only
code under `R/` forms the package API and therefore must be declared.

## Usage

``` r
PACKAGE_API_DIRS
```
