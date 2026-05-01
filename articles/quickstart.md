# Quickstart Guide: zzrenvcheck

## Overview

**zzrenvcheck** validates that all R packages used in your code are
properly declared in DESCRIPTION and locked in renv.lock, maintaining
reproducible environments for collaborative research.

## Installation

``` r

# Install from GitHub
remotes::install_github("rgt47/zzrenvcheck")
```

``` r

library(zzrenvcheck)
```

## Basic Usage

### Check Your Project

``` r

# Validate current project
check_packages()
```

This scans your code for package usage and compares against DESCRIPTION
and renv.lock.

### Auto-Fix Missing Packages

``` r

# Add missing packages automatically
fix_packages()
```

This queries CRAN/Bioconductor to find and add missing packages.

### Generate Status Report

``` r

# Get detailed status
report <- report_packages()
print(report)

# Output:
#   package         in_code in_description in_renv_lock status
#   dplyr           TRUE    FALSE          FALSE        missing_description
#   ggplot2         TRUE    TRUE           TRUE         ok
```

## Key Features

### Package Detection Patterns

The package detects packages from:

- [`library(dplyr)`](https://dplyr.tidyverse.org) - Direct library calls
- [`require(ggplot2)`](https://ggplot2.tidyverse.org) - Conditional
  loading
- `tidyr::pivot_longer()` - Namespace calls
- `#' @importFrom dplyr filter` - Roxygen imports

### Smart Filtering

19 filters avoid false positives:

- Base R packages (base, utils, stats)
- Placeholder names (myproject, package, foo)
- Generic words (my, your, file, path)
- Invalid package names

### Validation Modes

``` r

# Standard mode (R/, scripts/, analysis/)
check_packages(strict = FALSE)

# Strict mode (includes tests/, vignettes/, inst/)
check_packages(strict = TRUE)
```

## Sync to Code

Make code the single source of truth:

``` r

# Sync DESCRIPTION and renv.lock to match code
sync_packages()

# Preview changes first
sync_packages(dry_run = TRUE)
```

This adds missing packages and removes unused ones.

## Package Source Validation

Check if packages exist on CRAN, Bioconductor, or GitHub:

``` r

# Single package
is_installable("dplyr")
# Returns: list(installable = TRUE, source = "CRAN", package = "dplyr")

# Batch validation
check_installable(c("dplyr", "DESeq2", "NonExistent"))
```

## Workflow Integration

### Pre-Commit

``` bash
# In pre-commit hook
Rscript -e 'zzrenvcheck::check_packages(auto_fix = FALSE)'
```

### CI/CD Pipeline

``` yaml
# .github/workflows/check.yaml
- name: Check dependencies
  run: Rscript -e 'zzrenvcheck::check_packages()'
```

### Makefile Integration

``` makefile
check-renv:
    Rscript -e 'zzrenvcheck::check_packages()'
```

## Standalone Shell Script

For environments without R:

``` bash
# Install shell script version
cd zzrenvcheck
./install.sh --prefix ~/bin

# Use anywhere
zzrenvcheck --fix --strict --verbose
```

Features:

- No R installation required
- Uses grep, sed, awk, jq, curl
- Perfect for CI/CD pipelines

## Function Reference

| Function | Purpose |
|:---|:---|
| [`check_packages()`](https://rgt47.github.io/zzrenvcheck/reference/check_packages.md) | Main validation |
| [`fix_packages()`](https://rgt47.github.io/zzrenvcheck/reference/fix_packages.md) | Auto-fix wrapper |
| [`sync_packages()`](https://rgt47.github.io/zzrenvcheck/reference/sync_packages.md) | Sync to code |
| [`report_packages()`](https://rgt47.github.io/zzrenvcheck/reference/report_packages.md) | Status report |
| [`clean_description()`](https://rgt47.github.io/zzrenvcheck/reference/clean_description.md) | Remove unused |
| [`is_installable()`](https://rgt47.github.io/zzrenvcheck/reference/is_installable.md) | Check CRAN/Bioconductor |
| [`extract_code_packages()`](https://rgt47.github.io/zzrenvcheck/reference/extract_code_packages.md) | Scan code |

## Common Workflows

### Fix Missing Packages

``` r

# Check and fix
result <- check_packages(auto_fix = TRUE)

# Then commit
system("git add DESCRIPTION renv.lock")
system('git commit -m "Add missing packages"')
```

### Cleanup Unused Packages

``` r

# Remove packages no longer in code
clean_description()
sync_packages()
```

### Programmatic Use

``` r

result <- check_packages(auto_fix = FALSE)

if (result$status == "fail") {
  cat("Missing packages:\n")
  print(result$missing_in_description)
}
```

## Next Steps

- [`?check_packages`](https://rgt47.github.io/zzrenvcheck/reference/check_packages.md) -
  Main function documentation
- [`?sync_packages`](https://rgt47.github.io/zzrenvcheck/reference/sync_packages.md) -
  Sync workflow details
- GitHub: <https://github.com/rgt47/zzrenvcheck>
