# zzrenvcheck

> **Validate R Package Dependencies for Reproducibility**

[![License: GPL-3](https://img.shields.io/badge/License-GPL%203-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

## Overview

`zzrenvcheck` ensures all R packages used in your code are properly declared in `DESCRIPTION` and locked in `renv.lock`, maintaining reproducible environments for collaborative research.

**The Problem**: R projects often have undocumented dependencies, leading to:
- ❌ "Package not found" errors for collaborators
- ❌ Broken reproducibility
- ❌ Manual dependency management

**The Solution**: `zzrenvcheck` automatically:

- Scans code for package usage (`library()`, `require()`, `pkg::function()`)
- Validates DESCRIPTION and renv.lock consistency
- Auto-fixes missing packages via CRAN/Bioconductor/GitHub validation
- Syncs dependencies to code (removes unused, adds missing)
- Works cross-platform (Windows/macOS/Linux)

## Installation

### R Package (Recommended for R users)

```r
# From GitHub
remotes::install_github("rgt47/zzrenvcheck")

# From source (development)
cd ~/prj/d10/zzrenvcheck
R CMD INSTALL .
```

### Standalone Shell Script (No R required!)

Perfect for CI/CD, Docker environments, or systems without R:

```bash
# Clone the repository
git clone https://github.com/rgt47/zzrenvcheck.git
cd zzrenvcheck

# Install to ~/bin (default)
./install.sh

# Or install to custom location
./install.sh --prefix ~/.local

# Or install with custom name
./install.sh --name check-packages

# Now use it anywhere (if ~/bin is in your PATH)
zzrenvcheck --fix --strict --verbose
```

The standalone version:
- ✅ Works without R installation
- ✅ Uses only shell tools (grep, sed, awk, jq, curl)
- ✅ Perfect for CI/CD pipelines
- ✅ Can validate and auto-fix via CRAN API

## Quick Start

```r
library(zzrenvcheck)

# Check your project
check_packages()

# Auto-fix missing packages
fix_packages()

# View detailed report
report <- report_packages()
print(report)
```

## Features

### 📦 Comprehensive Package Detection

Finds packages from multiple sources:
- `library(dplyr)` - Direct library calls
- `require(ggplot2)` - Conditional loading
- `tidyr::pivot_longer()` - Namespace calls
- `#' @importFrom dplyr filter` - Roxygen imports

### 🧹 Smart Filtering

Applies 19 filters to avoid false positives:
- Base R packages (base, utils, stats, etc.)
- Placeholder names (myproject, package, foo, bar)
- Generic words (my, your, file, path)
- Invalid package names

### 🔧 Auto-Fix Capabilities

```r
# Automatically adds missing packages
fix_packages()

# Output:
# ℹ Auto-Fixing DESCRIPTION
# ✔ Added dplyr to DESCRIPTION Imports
# ✔ Added dplyr (1.1.4) to renv.lock
# ✔ All packages added
```

### 📊 Status Reports

```r
status <- report_packages()

# Output:
#   package         in_code in_description in_renv_lock status
#   dplyr           TRUE    FALSE          FALSE        missing_description
#   ggplot2         TRUE    TRUE           TRUE         ok
```

## Workflow Integration

### Pre-Commit Validation

```bash
# In your project
Rscript -e 'zzrenvcheck::check_packages(auto_fix = FALSE)'
```

### CI/CD Pipeline

```yaml
# .github/workflows/check-packages.yaml
- name: Check dependencies
  run: Rscript -e 'zzrenvcheck::check_packages()'
```

### Docker Integration

```bash
# Before building Docker image
make check-renv  # Uses validation.sh (shell version)

# Or use R package
Rscript -e 'zzrenvcheck::check_packages()'
```

## Functions

### Main Functions

| Function | Purpose |
|----------|---------|
| `check_packages()` | Main validation (detects and optionally fixes issues) |
| `fix_packages()` | Auto-fix convenience wrapper |
| `sync_packages()` | Sync DESCRIPTION/renv.lock to code (code as source of truth) |
| `report_packages()` | Generate status report without changes |
| `clean_description()` | Remove unused packages from DESCRIPTION |

### Validation Functions

| Function | Purpose |
|----------|---------|
| `is_installable()` | Check if package exists on CRAN/Bioconductor/GitHub |
| `check_installable()` | Batch validation of multiple packages |

### Extraction Functions

| Function | Purpose |
|----------|---------|
| `extract_code_packages()` | Extract package references from R code |
| `clean_package_names()` | Validate and filter package names |

### Parsing Functions

| Function | Purpose |
|----------|---------|
| `parse_description_imports()` | Parse DESCRIPTION Imports field |
| `parse_renv_lock()` | Parse renv.lock packages |
| `create_renv_lock()` | Create new renv.lock file |
| `remove_from_renv_lock()` | Remove packages from renv.lock |

## Examples

### Basic Usage

```r
library(zzrenvcheck)

# Validate current project
check_packages()

# Validation in strict mode (includes tests/ and vignettes/)
check_packages(strict = TRUE)

# Non-strict mode (only R/, scripts/, analysis/)
check_packages(strict = FALSE)
```

### Auto-Fix Workflow

```r
# Check and fix automatically
fix_packages()

# Then commit changes
system("git add DESCRIPTION renv.lock")
system('git commit -m "Add missing packages"')
```

### Programmatic Use

```r
result <- check_packages(auto_fix = FALSE)

if (result$status == "fail") {
  cat("Missing packages:\n")
  print(result$missing_in_description)
}
```

### Sync to Code (Cleanup Mode)

Sync DESCRIPTION and renv.lock to match your code exactly. Code is treated
as the single source of truth:

```r
# Sync packages (adds missing, removes unused)
sync_packages()

# Or use check_packages with cleanup flag
check_packages(cleanup = TRUE)

# Preview changes without applying
sync_packages(dry_run = TRUE)
```

### Package Source Validation

Check if packages are installable from CRAN, Bioconductor, or GitHub:

```r
# Check single package
is_installable("dplyr")
# Returns: list(installable = TRUE, source = "CRAN", package = "dplyr")

# Batch validation
check_installable(c("dplyr", "DESeq2", "NonExistent"))
# Returns data frame with installable status and source for each
```

## Comparison with validation.sh

`zzrenvcheck` provides both an R package and a standalone shell script:

| Feature | validation.sh (zzcollab) | zzrenvcheck (R pkg) |
|---------|--------------------------|---------------------|
| **Platform** | macOS/Linux | Windows/macOS/Linux |
| **Requires R** | No | Yes |
| **CRAN validation** | Yes | Yes |
| **Bioconductor validation** | Yes | Yes |
| **GitHub validation** | Yes | Yes |
| **Sync to code (cleanup)** | Yes | Yes |
| **Remove unused packages** | Yes | Yes |
| **Create renv.lock** | Yes | Yes |
| **Documentation** | `--help` | Built-in `?help` |
| **Testing** | Manual | testthat (101 tests) |
| **Output Format** | Colored CLI | Rich CLI (cli pkg) |

**Recommendation**:

- **R package**: R-based workflows, Windows users, RStudio integration
- **validation.sh (zzcollab)**: CI/CD, Docker host, no R installation

## Configuration

### Directory Scanning

```r
# Standard mode (default)
check_packages(strict = FALSE)
# Scans: R/, scripts/, analysis/

# Strict mode
check_packages(strict = TRUE)
# Scans: R/, scripts/, analysis/, tests/, vignettes/, inst/
```

### Verbosity

```r
# Verbose (default) - shows all issues
check_packages(verbose = TRUE)

# Quiet - shows only counts
check_packages(verbose = FALSE)
```

## Development Status

**Version**: 0.1.0.9000 (Development)

**Implemented**:

- Core extraction functions
- Package name cleaning (19 filters)
- DESCRIPTION/renv.lock parsing
- Validation logic with installable vs non-installable reporting
- Auto-fix via CRAN API
- Bioconductor package validation
- GitHub package validation
- Sync to code (cleanup mode)
- Remove unused packages from DESCRIPTION and renv.lock
- Create renv.lock from scratch
- CLI output with `cli` package
- Comprehensive test suite (101 tests)

**Planned** (v0.2.0):

- RStudio Addin
- Configuration file (`.zzrenvcheck.yaml`)
- Pre-commit hook installer

## Contributing

Contributions welcome! This package is part of the [zzcollab](https://github.com/rgt47/zzcollab) ecosystem.

## License

GPL-3 | See [LICENSE](LICENSE) file

## Related Projects

- **zzcollab**: Docker-based reproducible research framework
- **validation.sh**: Shell script version (no R required)
- **renv**: R package dependency management

## Citation

```
@software{zzrenvcheck2025,
  title = {zzrenvcheck: Validate R Package Dependencies for Reproducibility},
  author = {{zzcollab authors}},
  year = {2025},
  url = {https://github.com/rgt47/zzrenvcheck}
}
```

---

**Built with ❤️ by the zzcollab team**
