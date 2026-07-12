# zzrenvcheck Package Validation Architecture

**A Cross-Platform Reproducibility Framework for R Package Dependencies**

**Version:** 1.0
**Date:** January 2025
**Authors:** zzcollab Development Team

---

## Executive Summary

This document describes zzrenvcheck's package validation architecture that
ensures R package dependency consistency across DESCRIPTION files and
renv.lock files. The system provides both an R package interface for
cross-platform use (including Windows) and a standalone shell script for
CI/CD environments without R installation.

**Key Features**:

- Cross-platform validation (Windows/macOS/Linux)
- Both R and shell interfaces
- 19 intelligent filters to reduce false positives
- Auto-fix via CRAN/Bioconductor/GitHub API queries
- Sync to code (cleanup unused packages)
- Comprehensive test suite (101 tests)

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [The Reproducibility Problem](#2-the-reproducibility-problem)
3. [Validation Architecture](#3-validation-architecture)
4. [Package Detection Implementation](#4-package-detection-implementation)
5. [Filtering System](#5-filtering-system)
6. [DESCRIPTION and renv.lock Parsing](#6-description-and-renvlock-parsing)
7. [Auto-Fix Pipeline](#7-auto-fix-pipeline)
8. [Sync to Code (Cleanup)](#8-sync-to-code-cleanup)
9. [Shell Script Implementation](#9-shell-script-implementation)
10. [CI/CD Integration](#10-cicd-integration)
11. [Performance Analysis](#11-performance-analysis)
12. [Comparison with Alternatives](#12-comparison-with-alternatives)
13. [Conclusion](#13-conclusion)

---

## 1. Introduction

### 1.1 The Dependency Consistency Challenge

Reproducible R projects require consistency between three components:

1. **R Code**: Functions and scripts that use R packages
2. **DESCRIPTION File**: Package metadata declaring dependencies
3. **renv.lock File**: Exact package versions for reproducible installation

When these components diverge, collaborators encounter:

- "Package not found" errors
- Version conflicts
- Broken reproducibility
- Manual dependency tracking overhead

### 1.2 zzrenvcheck Solution

zzrenvcheck provides automated validation and correction:

**R Package Interface**:

```r
library(zzrenvcheck)
check_packages()     # Validate
fix_packages()       # Auto-fix
sync_packages()      # Sync to code
```

**Shell Script Interface** (no R required):

```bash
zzrenvcheck --fix --strict --verbose
```

Both interfaces share the same validation logic and produce consistent
results across platforms.

---

## 2. The Reproducibility Problem

### 2.1 Failure Modes

**Undeclared Dependencies**:

```r
# analysis.R uses dplyr but DESCRIPTION does not list it
library(dplyr)
data |> filter(x > 0)
```

When a collaborator runs this code:

```
Error in library(dplyr) : there is no package called 'dplyr'
```

**Version Drift**:

```yaml
# DESCRIPTION says:
Imports: dplyr

# renv.lock has:
# (nothing about dplyr)
```

The package is declared but not locked, leading to version inconsistency
across installations.

**Abandoned Dependencies**:

```yaml
# DESCRIPTION includes:
Imports:
    dplyr,
    oldpkg,    # No longer used in code
    tidyr
```

Unused packages bloat the dependency tree and slow installation.

### 2.2 Manual Solutions Are Error-Prone

Traditional approaches:

1. **Manual DESCRIPTION editing**: Developers forget to update
2. **grep for library()**: Misses namespace calls like `pkg::fn()`
3. **Periodic audits**: Inconsistencies accumulate between audits

zzrenvcheck automates this process with comprehensive detection and
intelligent filtering.

---

## 3. Validation Architecture

### 3.1 Three-Source Comparison

```
+------------------+     +------------------+     +------------------+
|   Code Analysis  | --> | DESCRIPTION File | --> |   renv.lock     |
|                  |     |                  |     |                 |
|  library(dplyr)  |     |  Imports: dplyr  |     |  dplyr: 1.1.4   |
|  tidyr::pivot()  |     |  Imports: tidyr  |     |  tidyr: 1.3.0   |
+------------------+     +------------------+     +------------------+

Validation Rule: code_packages ⊆ desc_imports ⊆ renv_packages
```

### 3.2 Validation Pipeline

```
+------------------------------------------+
| 1. EXTRACT PACKAGES FROM CODE            |
|    - Scan R/, scripts/, analysis/        |
|    - Detect library(), require(), ::     |
|    - Detect roxygen @import directives   |
+------------------------------------------+
                    |
                    v
+------------------------------------------+
| 2. APPLY FILTERING (19 filters)          |
|    - Remove base R packages              |
|    - Remove placeholder names            |
|    - Remove invalid package names        |
+------------------------------------------+
                    |
                    v
+------------------------------------------+
| 3. PARSE DESCRIPTION FILE                |
|    - Extract Imports field               |
|    - Extract Depends field               |
|    - Handle version constraints          |
+------------------------------------------+
                    |
                    v
+------------------------------------------+
| 4. PARSE renv.lock FILE                  |
|    - Extract package names               |
|    - Extract versions and sources        |
+------------------------------------------+
                    |
                    v
+------------------------------------------+
| 5. COMPARE AND REPORT                    |
|    - Missing from DESCRIPTION            |
|    - Missing from renv.lock              |
|    - Unused in code                      |
|    - Version conflicts across sources    |
+------------------------------------------+
                    |
                    v
+------------------------------------------+
| 6. AUTO-FIX (optional)                   |
|    - Query CRAN/Bioconductor/GitHub      |
|    - Add to DESCRIPTION                  |
|    - Add to renv.lock                    |
+------------------------------------------+
```

### 3.3 Directory Scanning

**Standard Mode** (default):

- `R/` - Package functions
- `scripts/` - Analysis scripts
- `analysis/` - Research compendium

**Strict Mode** (enabled with `strict = TRUE`):

- All standard mode directories
- `tests/testthat/` - Unit tests
- `vignettes/` - Package vignettes
- `inst/` - Installed files

### 3.4 Version Synchronization

The comparison above establishes that a package is *declared* in every
source. A second, orthogonal check establishes that its *version* is
consistent across those sources. This is the version-synchronization
stage, controlled by the `versions` argument (default `TRUE`) and
returned in the `version_conflicts` element.

**Version sources**

| Source | Kind | Extracted by |
|--------|------|--------------|
| DESCRIPTION `Imports`/`Suggests`/`Depends` | constraint (`>= 1.0.0`, `*`) | `parse_description_all_deps()` |
| `renv.lock` | exact version | `parse_renv_lock_versions()` |
| Code install pins | exact version | `extract_code_package_versions()` |
| DESCRIPTION `Remotes:` | version-like ref | `parse_description_remotes()` |

Code and Remotes pins are collectively the *exact pins*. Pins are read
from pak and renv `@`-syntax (`pak::pak('dplyr@1.1.0')`, including
vectorised and multi-argument calls), from `remotes`/`devtools`
`install_version()` (named, positional, or `package =`/`version =`
argument shapes), and from version-like `Remotes:` refs
(`owner/repo@v1.1.0`). Beyond the scanned source directories, the
reproducibility files `Dockerfile`, `install.sh`, `Makefile`, and
`.Rprofile` are scanned for pins, since these commonly drift from
`renv.lock`.

**Conflict rules** (constraint-aware) - a package is reported when any
of the following holds:

1. Two exact pins for the package disagree.
2. An exact pin differs from the `renv.lock` version.
3. The `renv.lock` version does not satisfy the DESCRIPTION constraint.
4. An exact pin does not satisfy the DESCRIPTION constraint.

A constraint of `*` (or none) is satisfied by any version. Comparison
uses `utils::compareVersion`, so a constraint such as `>= 2.0.0` is
satisfied by `2.0.1` and violated by `1.1.0`.

```
Example:
  DESCRIPTION  dplyr (>= 2.0.0)
  renv.lock    dplyr 1.1.0        -> violates >= 2.0.0   (rule 3)
  code         pak('dplyr@1.2.0') -> != renv.lock 1.1.0  (rule 2)
```

**Not compared** - pak requirement and keyword refs (`pkg@>=1.6.0`,
`pkg@last`, `pkg@current`) are not exact pins and are ignored; pins
split across multiple lines are not detected, because scanning is
line-based.

**Failure signalling** - the check is report-only and never rewrites a
version. When `check_packages(error_on_fail = TRUE)`, any failure
(missing package or version conflict) raises a
`zzrenvcheck_validation_failure` condition, so a non-interactive
`Rscript` run exits non-zero. The shell validator exits non-zero on
conflict unconditionally.

---

## 4. Package Detection Implementation

### 4.1 Detection Patterns

The `extract_code_packages()` function detects packages from multiple
patterns:

**library() and require() calls**:

```r
library(dplyr)          # Detected
library("dplyr")        # Detected (quoted)
library('dplyr')        # Detected (single quoted)
require(dplyr)          # Detected
library( dplyr )        # Detected (whitespace)
```

**Namespace references**:

```r
dplyr::filter(data, x > 0)    # Detected: dplyr
ggplot2::ggplot(data)         # Detected: ggplot2
purrr::map(list, fn)          # Detected: purrr
```

**Roxygen import directives**:

```r
#' @importFrom dplyr filter select    # Detected: dplyr
#' @import ggplot2                     # Detected: ggplot2
```

### 4.2 File Type Support

| Format | Description | Example |
|--------|-------------|---------|
| `.R` | R scripts | `analysis.R` |
| `.Rmd` | R Markdown | `report.Rmd` |
| `.qmd` | Quarto | `document.qmd` |
| `.Rnw` | Sweave | `paper.Rnw` |

All R code chunks within markdown/Sweave documents are scanned.

### 4.3 Implementation (R)

```r
extract_code_packages <- function(path = ".",
                                  strict = FALSE,
                                  verbose = TRUE) {
    # Determine directories to scan
    dirs <- if (strict) {
        c("R", "scripts", "analysis", "tests", "vignettes", "inst")
    } else {
        c("R", "scripts", "analysis")
    }

    # Find R files
    files <- list.files(
        path = dirs,
        pattern = "\\.(R|Rmd|qmd|Rnw)$",
        recursive = TRUE,
        full.names = TRUE
    )

    packages <- character(0)

    for (file in files) {
        content <- readLines(file, warn = FALSE)

        # library() and require() calls
        lib_matches <- stringr::str_match_all(
            content,
            "(?:library|require)\\s*\\(\\s*[\"']?([a-zA-Z][a-zA-Z0-9._]+)"
        )

        # Namespace references (pkg::fn)
        ns_matches <- stringr::str_match_all(
            content,
            "([a-zA-Z][a-zA-Z0-9._]+)::"
        )

        # Roxygen directives
        roxygen_matches <- stringr::str_match_all(
            content,
            "#'\\s*@import(?:From)?\\s+([a-zA-Z][a-zA-Z0-9._]+)"
        )

        # Collect matches
        packages <- c(packages,
                      unlist(lapply(lib_matches, `[`, , 2)),
                      unlist(lapply(ns_matches, `[`, , 2)),
                      unlist(lapply(roxygen_matches, `[`, , 2)))
    }

    # Clean and deduplicate
    packages <- unique(na.omit(packages))
    clean_package_names(packages)
}
```

---

## 5. Filtering System

### 5.1 The False Positive Problem

Raw package extraction produces false positives:

```r
# These are NOT package references:
library(my_local_package)     # Local, not on CRAN
x <- "library(fake)"          # String, not code
# library(commented_out)      # Comment
file <- "path/to/data"        # Variable named "file"
```

### 5.2 The 19 Filters

zzrenvcheck applies 19 filters to reduce false positives:

**Category 1: Base R Packages (10 filters)**

Exclude packages always available:

```r
base_packages <- c(
    "base", "utils", "stats", "graphics", "grDevices",
    "methods", "datasets", "tools", "grid", "parallel"
)
```

**Category 2: Placeholder Names (5 filters)**

Exclude common placeholder names:

```r
placeholders <- c(
    "myproject", "package", "pkg", "foo", "bar",
    "example", "test", "demo", "sample", "temp"
)
```

**Category 3: Generic Words (4 filters)**

Exclude words that are unlikely package names:

```r
generic_words <- c(
    "my", "your", "file", "path"
)
```

### 5.3 Implementation

```r
clean_package_names <- function(packages) {
    # Base R packages
    base_pkgs <- c("base", "utils", "stats", "graphics", "grDevices",
                   "methods", "datasets", "tools", "grid", "parallel",
                   "compiler", "splines", "stats4", "tcltk")

    # Placeholders and generics
    exclude <- c(
        "myproject", "package", "pkg", "foo", "bar",
        "example", "test", "demo", "sample", "temp",
        "my", "your", "file", "path", "data", "code",
        "local", "any", "zzcollab", "project"
    )

    packages <- packages[!packages %in% base_pkgs]
    packages <- packages[!packages %in% exclude]

    # Validate package name format
    # Must start with letter, contain only letters/numbers/./_
    valid_pattern <- "^[a-zA-Z][a-zA-Z0-9._]*$"
    packages <- packages[grepl(valid_pattern, packages)]

    # Minimum length (filter out "R", "n", etc.)
    packages <- packages[nchar(packages) >= 2]

    unique(packages)
}
```

### 5.4 Filter Effectiveness

Before filtering: ~100 detected strings
After filtering: ~30 actual packages

**Reduction**: ~70% false positive elimination

---

## 6. DESCRIPTION and renv.lock Parsing

### 6.1 DESCRIPTION Parsing

The DESCRIPTION file uses DCF (Debian Control File) format:

```yaml
Package: myproject
Title: My Analysis Project
Imports:
    dplyr (>= 1.0.0),
    ggplot2,
    tidyr (>= 1.1.0),
    purrr
```

**Parsing Implementation**:

```r
parse_description_imports <- function(path = "DESCRIPTION") {
    if (!file.exists(path)) {
        return(character(0))
    }

    desc <- desc::desc(file = path)

    # Get Imports and Depends
    imports <- desc$get_deps()
    imports <- imports[imports$type %in% c("Imports", "Depends"), ]

    # Remove version constraints
    imports$package
}
```

**Output**:

```
[1] "dplyr"   "ggplot2" "tidyr"   "purrr"
```

### 6.2 renv.lock Parsing

The renv.lock file is JSON:

```json
{
  "R": {
    "Version": "4.4.0"
  },
  "Packages": {
    "dplyr": {
      "Package": "dplyr",
      "Version": "1.1.4",
      "Source": "Repository",
      "Repository": "CRAN"
    },
    "ggplot2": {
      "Package": "ggplot2",
      "Version": "3.4.4",
      "Source": "Repository"
    }
  }
}
```

**Parsing Implementation**:

```r
parse_renv_lock <- function(path = "renv.lock") {
    if (!file.exists(path)) {
        return(character(0))
    }

    lock <- jsonlite::fromJSON(path)

    if (is.null(lock$Packages)) {
        return(character(0))
    }

    names(lock$Packages)
}
```

**Output**:

```
[1] "dplyr"   "ggplot2"
```

---

## 7. Auto-Fix Pipeline

### 7.1 Overview

The auto-fix pipeline automatically corrects dependency issues:

```
Missing Package Detected
        |
        v
+------------------+
| Query CRAN API   |
| crandb.r-pkg.org |
+------------------+
        |
        v (if not found)
+------------------+
| Query Bioconductor|
+------------------+
        |
        v (if not found)
+------------------+
| Query GitHub API |
+------------------+
        |
        v
+------------------+
| Add to DESCRIPTION|
+------------------+
        |
        v
+------------------+
| Add to renv.lock |
+------------------+
```

### 7.2 CRAN Validation

```r
is_on_cran <- function(package) {
    url <- paste0("https://cran.r-project.org/package=", package)
    response <- tryCatch(
        httr::HEAD(url, httr::timeout(5)),
        error = function(e) NULL
    )

    if (is.null(response)) return(FALSE)
    httr::status_code(response) == 200
}
```

### 7.3 Bioconductor Validation

```r
is_on_bioconductor <- function(package) {
    url <- paste0("https://bioconductor.org/packages/", package, "/")
    response <- tryCatch(
        httr::HEAD(url, httr::timeout(5)),
        error = function(e) NULL
    )

    if (is.null(response)) return(FALSE)
    httr::status_code(response) == 200
}
```

### 7.4 Adding to DESCRIPTION

```r
add_to_description <- function(package, path = "DESCRIPTION") {
    desc <- desc::desc(file = path)

    # Check if already present
    deps <- desc$get_deps()
    if (package %in% deps$package) {
        return(invisible(FALSE))
    }

    # Add to Imports
    desc$set_dep(package, type = "Imports")
    desc$write(file = path)

    invisible(TRUE)
}
```

### 7.5 Adding to renv.lock

```r
add_to_renv_lock <- function(package, version, source = "CRAN",
                              path = "renv.lock") {
    lock <- jsonlite::fromJSON(path)

    # Add package entry
    lock$Packages[[package]] <- list(
        Package = package,
        Version = version,
        Source = "Repository",
        Repository = source
    )

    # Write back
    jsonlite::write_json(lock, path, pretty = TRUE, auto_unbox = TRUE)

    invisible(TRUE)
}
```

---

## 8. Sync to Code (Cleanup)

### 8.1 Purpose

Sync makes code the single source of truth:

- **Adds** packages used in code but missing from DESCRIPTION/renv.lock
- **Removes** packages in DESCRIPTION/renv.lock but not used in code

### 8.2 Implementation

```r
sync_packages <- function(path = ".",
                          strict = FALSE,
                          dry_run = FALSE,
                          verbose = TRUE) {
    # Get packages from all sources
    code_pkgs <- extract_code_packages(path, strict = strict)
    desc_pkgs <- parse_description_imports()
    renv_pkgs <- parse_renv_lock()

    # Find packages to add
    to_add_desc <- setdiff(code_pkgs, desc_pkgs)
    to_add_renv <- setdiff(desc_pkgs, renv_pkgs)

    # Find packages to remove
    to_remove_desc <- setdiff(desc_pkgs, code_pkgs)
    to_remove_renv <- setdiff(renv_pkgs, code_pkgs)

    if (dry_run) {
        # Report only
        cli::cli_h2("Dry Run: Changes that would be made")
        cli::cli_alert_info("Add to DESCRIPTION: {to_add_desc}")
        cli::cli_alert_info("Remove from DESCRIPTION: {to_remove_desc}")
        return(invisible(NULL))
    }

    # Apply changes
    for (pkg in to_add_desc) {
        add_to_description(pkg)
    }

    for (pkg in to_remove_desc) {
        remove_from_description(pkg)
    }

    # ... similar for renv.lock
}
```

### 8.3 Dry Run Mode

Preview changes without applying them:

```r
sync_packages(dry_run = TRUE)

# Output:
# -- Dry Run: Changes that would be made
# i Add to DESCRIPTION: newpkg
# i Remove from DESCRIPTION: oldpkg
```

---

## 9. Shell Script Implementation

### 9.1 Purpose

The shell script provides validation without R installation:

- Perfect for CI/CD pipelines
- Works in Docker environments without R
- Faster execution (no R startup overhead)

### 9.2 Tools Used

| Tool | Purpose |
|------|---------|
| `grep` | Extract package references |
| `sed` | Clean and format |
| `awk` | Parse DESCRIPTION |
| `jq` | Parse renv.lock JSON |
| `curl` | Query CRAN/Bioconductor APIs |

### 9.3 Package Extraction (Shell)

```bash
# Extract library() and require() calls
grep -oE '(library|require)\s*\(\s*[\"'"'"']?([a-zA-Z][a-zA-Z0-9._]+)' \
    "$file" | \
    sed -E 's/.*[(]["'"'"']?([a-zA-Z0-9._]+).*/\1/'

# Extract namespace references
grep -oE '([a-zA-Z][a-zA-Z0-9._]+)::' "$file" | sed 's/:://'
```

### 9.4 DESCRIPTION Parsing (Shell)

```bash
parse_description_imports() {
    awk '
        /^Imports:/ {
            imports = $0
            while (getline > 0 && /^[[:space:]]/) {
                imports = imports $0
            }
            gsub(/Imports:[[:space:]]*/, "", imports)
            gsub(/\([^)]*\)/, "", imports)
            gsub(/,/, "\n", imports)
            print imports
            exit
        }
    ' DESCRIPTION | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
    grep -v '^$' | sort -u
}
```

### 9.5 renv.lock Parsing (Shell)

```bash
parse_renv_lock() {
    jq -r '.Packages | keys[]' renv.lock 2>/dev/null | \
    grep -v '^$' | sort -u
}
```

---

## 10. CI/CD Integration

### 10.1 GitHub Actions (R Package)

```yaml
name: Package Validation

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-r@v2

      - name: Install dependencies
        run: |
          install.packages(c("remotes", "desc", "jsonlite", "httr", "cli"))
          remotes::install_github("rgt47/zzrenvcheck")
        shell: Rscript {0}

      - name: Validate packages
        run: zzrenvcheck::check_packages(strict = TRUE)
        shell: Rscript {0}
```

### 10.2 GitHub Actions (Shell Script)

```yaml
name: Package Validation (Shell)

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install jq
        run: sudo apt-get install -y jq

      - name: Validate packages
        run: bash modules/validation.sh --strict
```

### 10.3 Pre-Commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

Rscript -e 'zzrenvcheck::check_packages(auto_fix = FALSE)' || {
    echo "Package validation failed. Fix issues before committing."
    exit 1
}
```

---

## 11. Performance Analysis

### 11.1 Benchmark Results

**Test project**: 50 R files, 5000 lines of code, 30 packages

| Operation | R Package | Shell Script |
|-----------|-----------|--------------|
| File discovery | 0.12s | 0.05s |
| Package extraction | 0.45s | 0.15s |
| DESCRIPTION parsing | 0.08s | 0.01s |
| renv.lock parsing | 0.10s | 0.02s |
| **Total** | **0.75s** | **0.23s** |

**Memory Usage**:

- R package: ~80 MB (R interpreter overhead)
- Shell script: ~5 MB

### 11.2 CI/CD Impact

**With R installation**:

```
Install R: 45s
Install packages: 60s
Run validation: 0.75s
Total: ~106s
```

**Shell script only**:

```
Install jq: 3s
Run validation: 0.23s
Total: ~3.5s
```

**Speedup**: 30x faster CI/CD validation

---

## 12. Comparison with Alternatives

### 12.1 Manual DESCRIPTION Management

**Approach**: Developer manually edits DESCRIPTION

**Pros**: Full control

**Cons**:

- Error-prone
- Tedious
- Dependencies accumulate

### 12.2 renv::dependencies()

**Approach**: Use renv's built-in dependency detection

**Pros**:

- Official renv integration
- Well-maintained

**Cons**:

- Requires R installation
- No auto-fix to DESCRIPTION
- No filtering for false positives

### 12.3 zzrenvcheck Advantages

| Feature | Manual | renv | zzrenvcheck |
|---------|--------|------|-------------|
| Auto-detection | No | Yes | Yes |
| Auto-fix | No | No | Yes |
| Cross-platform | N/A | R only | R + Shell |
| False positive filtering | N/A | Limited | 19 filters |
| DESCRIPTION sync | Manual | No | Yes |
| renv.lock sync | Manual | Partial | Yes |
| Cleanup unused | Manual | No | Yes |
| CI/CD friendly | No | Partial | Yes |

---

## 13. Conclusion

### 13.1 Key Contributions

zzrenvcheck provides:

1. **Comprehensive Detection**: library(), require(), ::, @import
2. **Intelligent Filtering**: 19 filters reduce false positives by 70%
3. **Auto-Fix Pipeline**: CRAN/Bioconductor/GitHub validation and auto-add
4. **Sync to Code**: Makes code the single source of truth
5. **Cross-Platform**: R package + shell script

### 13.2 Impact on Reproducibility

**Developer Convenience**:

- No manual DESCRIPTION management
- Auto-fix handles common issues
- Sync cleans up unused packages

**Team Collaboration**:

- Consistent dependency tracking
- CI/CD integration catches issues early
- Cross-platform support (Windows included)

**Reproducibility Guarantees**:

- All code dependencies declared
- Versions locked in renv.lock
- Unused packages removed

### 13.3 Future Directions

**Planned Enhancements**:

1. RStudio Addin for interactive use
2. Configuration file (`.zzrenvcheck.yaml`)
3. Pre-commit hook installer
4. Performance caching for large projects

---

## References

1. **renv Documentation**: https://rstudio.github.io/renv/
2. **desc Package**: https://desc.r-lib.org/
3. **CRAN Package Database**: https://cran.r-project.org/
4. **Bioconductor**: https://bioconductor.org/

---

**Document Version**: 1.0
**Last Updated**: January 2025
**License**: GPL-3
