# zzrenvcheck

> **Validate R Package Dependencies for Reproducibility**

## Overview

`zzrenvcheck` ensures all R packages used in project code are properly
declared in `DESCRIPTION` and locked in `renv.lock`, maintaining
reproducible environments for collaborative research.

**The Problem**: R projects often have undocumented dependencies,
leading to:

- ‘Package not found’ errors for collaborators
- Broken reproducibility
- Manual dependency management

**The Solution**: `zzrenvcheck` automatically:

- Scans code for package usage
  ([`library()`](https://rdrr.io/r/base/library.html),
  [`require()`](https://rdrr.io/r/base/library.html), `pkg::function()`)
- Validates DESCRIPTION and renv.lock consistency
- Auto-fixes missing packages via CRAN/Bioconductor/GitHub validation
- Syncs dependencies to code (removes unused, adds missing)
- Works cross-platform (Windows/macOS/Linux)

## Relationship to renv

`zzrenvcheck` complements `renv`; it does not replace it. The two answer
different questions:

- **renv** confirms the lockfile matches what is actually **installed**
  in the project library
  ([`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
  /
  [`renv::status()`](https://rstudio.github.io/renv/reference/status.html)
  read the installed packages).
- **zzrenvcheck** confirms the **code, `DESCRIPTION`, and `renv.lock`
  all agree** about which packages the project declares.

zzrenvcheck is **presence/declaration-only**: it reads source files and
the two manifests and never inspects an installed library. That is why
it needs no installed packages, no container, and no R at all in the
shell version, and can run on the host or in CI while the container
holds the real environment. renv guarantees installed-versus-locked;
zzrenvcheck guarantees used-versus-declared-versus-locked. Neither alone
covers both, so a typical pipeline runs
[`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
where the packages are installed (the container) and the `zzrenvcheck`
gate where the files live (the host or CI).

## Installation

### R Package (Recommended for R users)

``` r

# From GitHub
# install.packages('pak')
pak::pak('rgt47/zzrenvcheck')
```

From a local clone:

``` bash
R CMD INSTALL .
```

### Standalone Shell Script (No R required.)

Suitable for CI/CD, Docker environments, or systems without R:

``` bash
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

- Works without R installation
- Uses only shell tools (grep, sed, awk, jq, curl)
- Suitable for CI/CD pipelines
- Can validate and auto-fix via CRAN API
- Runs the same version-synchronization check as the R package
  (DESCRIPTION vs renv.lock vs code pins) and exits non-zero on a
  conflict, so `zzrenvcheck --no-fix` works as a CI gate

## Quick Start

``` r

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

### Package Detection Patterns

Finds packages from multiple sources: -
[`library(dplyr)`](https://dplyr.tidyverse.org) - Direct library calls -
[`require(ggplot2)`](https://ggplot2.tidyverse.org) - Conditional
loading - `tidyr::pivot_longer()` - Namespace calls -
`#' @importFrom dplyr filter` - Roxygen imports

### Version Synchronization

Beyond checking that a package is *declared*,
[`check_packages()`](https://rgt47.github.io/zzrenvcheck/reference/check_packages.md)
checks that its *version* is consistent across DESCRIPTION constraints,
`renv.lock`, and version-pinned installs in code. Comparison is
constraint-aware: an exact version must satisfy a DESCRIPTION
constraint, and two exact pins must agree.

``` r

check_packages()

# ── Version Conflicts ──
# x Found 1 package with inconsistent versions across DESCRIPTION,
#   renv.lock, and code
# ! dplyr: code pin 1.2.0 != renv.lock 1.1.0; renv.lock 1.1.0 violates
#   DESCRIPTION (>= 2.0.0)
# i Reproducibility requires matching versions across all sources.
```

Version pins are read from pak and renv `@`-syntax
(`pak::pak('dplyr@1.1.0')`, including vectorised and multi-argument
calls), from `remotes`/`devtools` `install_version()`, and from the
DESCRIPTION `Remotes:` field. In addition to the usual source
directories, the reproducibility files `Dockerfile`, `install.sh`,
`Makefile`, and `.Rprofile` are scanned, because pinned installs there
commonly drift from `renv.lock`.

The check is report-only (it never rewrites versions) and is controlled
by the `versions` argument (default `TRUE`). Conflicts are returned in
the `version_conflicts` element and set the result status to `fail`.

Two forms are deliberately not compared: pak requirement and keyword
refs (`pkg@>=1.6.0`, `pkg@last`, `pkg@current`), which are not exact
pins; and pins split across multiple lines, because scanning is
line-based.

### False Positive Filtering

Applies 19 filters to avoid false positives: - Base R packages (base,
utils, stats, etc.) - Placeholder names (myproject, package, foo, bar) -
Generic words (my, your, file, path) - Invalid package names

### Auto-Fix Capabilities

``` r

# Automatically adds missing packages
fix_packages()

# Output:
# Auto-Fixing DESCRIPTION
# Added dplyr to DESCRIPTION Imports
# Added dplyr (1.1.4) to renv.lock
# All packages added
```

### Status Reports

``` r

status <- report_packages()

# Output:
#   package         in_code in_description in_renv_lock status
#   dplyr           TRUE    FALSE          FALSE        missing_description
#   ggplot2         TRUE    TRUE           TRUE         ok
```

## Workflow Integration

### Pre-Commit Validation

``` bash
# In your project
Rscript -e 'zzrenvcheck::check_packages(auto_fix = FALSE)'
```

### CI/CD Pipeline

``` yaml
# .github/workflows/check-packages.yaml
- name: Check dependencies
  # error_on_fail = TRUE makes the run exit non-zero (failing the job)
  # when any package is missing or a version conflict is found.
  run: Rscript -e 'zzrenvcheck::check_packages(error_on_fail = TRUE)'
```

### Docker Integration

``` bash
# Before building Docker image
make check-renv  # Uses validation.sh (shell version)

# Or use R package
Rscript -e 'zzrenvcheck::check_packages()'
```

## Functions

### Main Functions

| Function | Purpose |
|----|----|
| [`check_packages()`](https://rgt47.github.io/zzrenvcheck/reference/check_packages.md) | Main validation (detects and optionally fixes issues) |
| [`fix_packages()`](https://rgt47.github.io/zzrenvcheck/reference/fix_packages.md) | Auto-fix convenience wrapper |
| [`sync_packages()`](https://rgt47.github.io/zzrenvcheck/reference/sync_packages.md) | Sync DESCRIPTION/renv.lock to code (code as source of truth) |
| [`report_packages()`](https://rgt47.github.io/zzrenvcheck/reference/report_packages.md) | Generate status report without changes |
| [`clean_description()`](https://rgt47.github.io/zzrenvcheck/reference/clean_description.md) | Remove unused packages from DESCRIPTION |

### Validation Functions

| Function | Purpose |
|----|----|
| [`is_installable()`](https://rgt47.github.io/zzrenvcheck/reference/is_installable.md) | Check if package exists on CRAN/Bioconductor/GitHub |
| [`check_installable()`](https://rgt47.github.io/zzrenvcheck/reference/check_installable.md) | Batch validation of multiple packages |

### Extraction Functions

| Function | Purpose |
|----|----|
| [`extract_code_packages()`](https://rgt47.github.io/zzrenvcheck/reference/extract_code_packages.md) | Extract package references from R code |
| [`extract_code_package_versions()`](https://rgt47.github.io/zzrenvcheck/reference/extract_code_package_versions.md) | Extract version-pinned installs (pak/renv `@`, `install_version()`) |
| [`clean_package_names()`](https://rgt47.github.io/zzrenvcheck/reference/clean_package_names.md) | Validate and filter package names |

### Parsing Functions

| Function | Purpose |
|----|----|
| [`parse_description_imports()`](https://rgt47.github.io/zzrenvcheck/reference/parse_description_imports.md) | Parse DESCRIPTION Imports field |
| [`parse_renv_lock()`](https://rgt47.github.io/zzrenvcheck/reference/parse_renv_lock.md) | Parse renv.lock packages |
| [`create_renv_lock()`](https://rgt47.github.io/zzrenvcheck/reference/create_renv_lock.md) | Create new renv.lock file |
| [`remove_from_renv_lock()`](https://rgt47.github.io/zzrenvcheck/reference/remove_from_renv_lock.md) | Remove packages from renv.lock |

## Examples

### Basic Usage

``` r

library(zzrenvcheck)

# Validate current project
check_packages()

# Validation in strict mode (includes tests/ and vignettes/)
check_packages(strict = TRUE)

# Non-strict mode (only R/, scripts/, analysis/)
check_packages(strict = FALSE)
```

### Auto-Fix Workflow

``` r

# Check and fix automatically
fix_packages()

# Then commit changes
system("git add DESCRIPTION renv.lock")
system('git commit -m "Add missing packages"')
```

### Programmatic Use

``` r

result <- check_packages(auto_fix = FALSE)

if (result$status == "fail") {
  cat("Missing packages:\n")
  print(result$missing_in_description)
}
```

### Sync to Code (Cleanup Mode)

Sync DESCRIPTION and renv.lock to match your code exactly. Code is
treated as the single source of truth:

``` r

# Sync packages (adds missing, removes unused)
sync_packages()

# Or use check_packages with cleanup flag
check_packages(cleanup = TRUE)

# Preview changes without applying
sync_packages(dry_run = TRUE)
```

### Package Source Validation

Check if packages are installable from CRAN, Bioconductor, or GitHub:

``` r

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
|----|----|----|
| **Platform** | macOS/Linux | Windows/macOS/Linux |
| **Requires R** | No | Yes |
| **CRAN validation** | Yes | Yes |
| **Bioconductor validation** | Yes | Yes |
| **GitHub validation** | Yes | Yes |
| **Sync to code (cleanup)** | Yes | Yes |
| **Remove unused packages** | Yes | Yes |
| **Create renv.lock** | Yes | Yes |
| **Documentation** | `--help` | Built-in [`?help`](https://rdrr.io/r/utils/help.html) |
| **Testing** | Manual | testthat (101 tests) |
| **Output Format** | Colored CLI | Rich CLI (cli pkg) |

**Recommendation**:

- **R package**: R-based workflows, Windows users, RStudio integration
- **validation.sh (zzcollab)**: CI/CD, Docker host, no R installation

## Configuration

### Directory Scanning

``` r

# Standard mode (default)
check_packages(strict = FALSE)
# Scans: R/, scripts/, analysis/

# Strict mode
check_packages(strict = TRUE)
# Scans: R/, scripts/, analysis/, tests/, vignettes/, inst/
```

### Verbosity

``` r

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

Contributions are welcome. This package is part of the
[zzcollab](https://github.com/rgt47/zzcollab) ecosystem.

## License

GPL (\>= 3). See <https://www.gnu.org/licenses/gpl-3.0> for details.

## Related Projects

- **zzcollab**: Docker-based reproducible research framework
- **validation.sh**: Shell script version (no R required)
- **renv**: R package dependency management

## Citation

    @software{zzrenvcheck,
      title = {zzrenvcheck: Validate R Package Dependencies for Reproducibility},
      author = {Thomas, Ronald G.},
      url = {https://github.com/rgt47/zzrenvcheck}
    }

------------------------------------------------------------------------

Developed by the zzcollab team.
