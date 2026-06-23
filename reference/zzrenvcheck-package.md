# zzrenvcheck: Validate R Package Dependencies for Reproducibility

Validates that all R packages used in source code are properly declared
in DESCRIPTION and locked in renv.lock for reproducibility.

## Main Functions

- [`check_packages`](https://rgt47.github.io/zzrenvcheck/reference/check_packages.md):
  Main validation function

- [`fix_packages`](https://rgt47.github.io/zzrenvcheck/reference/fix_packages.md):
  Auto-fix missing packages

- [`report_packages`](https://rgt47.github.io/zzrenvcheck/reference/report_packages.md):
  Generate package status report

- [`clean_description`](https://rgt47.github.io/zzrenvcheck/reference/clean_description.md):
  Remove unused packages

## Package Extraction

- [`extract_code_packages`](https://rgt47.github.io/zzrenvcheck/reference/extract_code_packages.md):
  Extract packages from R code

- [`clean_package_names`](https://rgt47.github.io/zzrenvcheck/reference/clean_package_names.md):
  Validate and clean package names

## Parsing

- [`parse_description_imports`](https://rgt47.github.io/zzrenvcheck/reference/parse_description_imports.md):
  Parse DESCRIPTION Imports

- [`parse_renv_lock`](https://rgt47.github.io/zzrenvcheck/reference/parse_renv_lock.md):
  Parse renv.lock packages

## See also

Useful links:

- <https://github.com/rgt47/zzrenvcheck>

- Report bugs at <https://github.com/rgt47/zzrenvcheck/issues>

## Author

**Maintainer**: Ronald (Ryy) G Thomas <rgthomas@ucsd.edu>
([ORCID](https://orcid.org/0000-0003-1686-4965))

Authors:

- Ronald (Ryy) G Thomas <rgthomas@ucsd.edu>
  ([ORCID](https://orcid.org/0000-0003-1686-4965))
