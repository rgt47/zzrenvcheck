# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Project Overview

**zzrenvcheck** is an R package that validates R package dependencies for
reproducibility. It ensures all packages used in code are properly declared
in DESCRIPTION and locked in renv.lock.

The package provides both an R interface and a standalone shell script for
CI/CD environments.

## Package Architecture

### Core Functions

| Function | Purpose |
|:---------|:--------|
| `check_packages()` | Main validation (detects and optionally fixes issues) |
| `fix_packages()` | Auto-fix convenience wrapper |
| `sync_packages()` | Sync DESCRIPTION/renv.lock to code |
| `report_packages()` | Generate status report without changes |
| `clean_description()` | Remove unused packages from DESCRIPTION |

### Extraction Functions

| Function | Purpose |
|:---------|:--------|
| `extract_code_packages()` | Extract package references from R code |
| `clean_package_names()` | Validate and filter package names (19 filters) |

### Parsing Functions

| Function | Purpose |
|:---------|:--------|
| `parse_description_imports()` | Parse DESCRIPTION Imports field |
| `parse_renv_lock()` | Parse renv.lock packages |
| `create_renv_lock()` | Create new renv.lock file |
| `remove_from_renv_lock()` | Remove packages from renv.lock |

### Validation Functions

| Function | Purpose |
|:---------|:--------|
| `is_installable()` | Check if package exists on CRAN/Bioconductor/GitHub |
| `check_installable()` | Batch validation of multiple packages |

## Common Commands

### Development

```bash
# Start Docker container
make r

# Run tests
make test

# Validate dependencies
make check-renv

# Build package
R CMD INSTALL .
```

### Testing

```r
# Run all tests
devtools::test()

# Run specific test file
testthat::test_file("tests/testthat/test-check_packages.R")
```

### Package Usage

```r
library(zzrenvcheck)

# Check project dependencies
check_packages()

# Auto-fix missing packages
fix_packages()

# Sync to code (code as source of truth)
sync_packages()

# Generate report
report <- report_packages()
print(report)
```

## Code Organization

```
zzrenvcheck/
├── R/                     # Package functions
│   ├── check_packages.R   # Main validation logic
│   ├── fix_packages.R     # Auto-fix functionality
│   ├── sync_packages.R    # Sync to code
│   ├── extract_code_packages.R  # Code scanning
│   ├── clean_package_names.R    # Name filtering
│   ├── parse_description.R      # DESCRIPTION parsing
│   ├── parse_renv_lock.R        # renv.lock parsing
│   ├── is_installable.R         # CRAN/Bioconductor/GitHub validation
│   └── utils.R            # Utility functions
├── tests/testthat/        # Test suite (101 tests)
├── man/                   # Generated documentation
├── modules/               # Shell script modules
│   └── validation.sh      # Standalone shell version
├── install.sh             # Shell script installer
├── DESCRIPTION            # Package metadata
├── NAMESPACE              # Exported functions
└── renv.lock              # Package versions
```

## Package Detection Patterns

The package scans for these patterns:

- `library(dplyr)` - Direct library calls
- `require(ggplot2)` - Conditional loading
- `tidyr::pivot_longer()` - Namespace calls
- `#' @importFrom dplyr filter` - Roxygen imports

## Filtering Logic (19 Filters)

The `clean_package_names()` function applies these filters:

1. Base R packages (base, utils, stats, etc.)
2. Placeholder names (myproject, package, foo, bar)
3. Generic words (my, your, file, path)
4. Invalid package names (numbers, special characters)
5. Duplicates
6. Empty strings

## Auto-Fix Workflow

When `fix_packages()` is called:

1. Scan code for package references
2. Compare with DESCRIPTION Imports
3. Check CRAN for missing packages
4. Add to DESCRIPTION if found
5. Update renv.lock with version info

## API Integration

### CRAN API

```r
# Check if package exists on CRAN
url <- paste0("https://cran.r-project.org/web/packages/", pkg, "/")
response <- httr::HEAD(url)
exists <- httr::status_code(response) == 200
```

### Bioconductor API

```r
# Check if package exists on Bioconductor
url <- paste0("https://bioconductor.org/packages/", pkg, "/")
response <- httr::HEAD(url)
exists <- httr::status_code(response) == 200
```

## Testing Strategy

- Unit tests for each extraction pattern
- Integration tests for full workflow
- Mock tests for API calls
- Edge case tests for unusual package names

## Dependencies

### Core

- `desc` - DESCRIPTION file manipulation
- `jsonlite` - JSON parsing (renv.lock)
- `cli` - Rich CLI output
- `httr` - HTTP requests for API validation

### Development

- `testthat` - Testing framework
- `withr` - Test isolation
- `fs` - File system operations

## Shell Script Version

The standalone shell script (`install.sh` + `modules/validation.sh`) provides:

- No R installation required
- CI/CD friendly
- Uses grep, sed, awk, jq, curl
- Same validation logic as R package

Installation:

```bash
./install.sh --prefix ~/bin --name zzrenvcheck
```

## Related Projects

- **zzcollab**: Docker-based reproducible research framework
- **renv**: R package dependency management

## Repository URL

https://github.com/rgt47/zzrenvcheck
