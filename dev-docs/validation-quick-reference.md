# Package Validation Quick Reference

**Purpose**: Fast reference for zzrenvcheck validation system and common
scenarios.

---

## Validation Commands

### R Package Interface

```r
library(zzrenvcheck)

# Check DESCRIPTION <-> renv.lock consistency
check_packages()

# Verbose output showing missing packages
check_packages(verbose = TRUE)

# Include tests/ and vignettes/ directories
check_packages(strict = TRUE)

# Skip the cross-source version check
check_packages(versions = FALSE)

# Exit non-zero on failure (for CI / Rscript)
check_packages(error_on_fail = TRUE)
```

### Shell Script Interface (No R Required)

```bash
# Basic validation
zzrenvcheck

# Verbose output
zzrenvcheck --verbose

# Strict mode (include tests/, vignettes/)
zzrenvcheck --strict

# Auto-fix missing packages
zzrenvcheck --fix

# Combined options
zzrenvcheck --fix --strict --verbose
```

---

## Common Scenarios

### Scenario 1: Add New Package

**Workflow (R)**:

```r
# 1. Add package to your code
# library(newpkg) or newpkg::function()

# 2. Run fix to add to DESCRIPTION and renv.lock
fix_packages()

# 3. Verify
check_packages()
```

**Result**: Package automatically added to DESCRIPTION and renv.lock.

---

### Scenario 2: Package Used But Not Declared

**Symptoms**:

```r
check_packages()
# x Package validation failed
# Missing packages: dplyr
```

**Solution**:

```r
fix_packages()
# i Auto-Fixing DESCRIPTION
# v Added dplyr to DESCRIPTION Imports
# v Added dplyr (1.1.4) to renv.lock
```

---

### Scenario 3: Package in Code But Not in DESCRIPTION

**Symptoms**:

```r
check_packages()
# x Package validation failed
# Packages used in code but not in DESCRIPTION: ggplot2
```

**Solution 1** (Recommended - Use fix_packages):

```r
fix_packages()
```

**Solution 2** (Manual edit):

Edit DESCRIPTION and add to Imports:

```yaml
Imports:
    ggplot2,
    dplyr
```

**Solution 3** (Remove from code if not needed):

Remove `library(ggplot2)` calls from code, then re-validate.

---

### Scenario 4: Package in DESCRIPTION But Not in renv.lock

**Symptoms**:

```r
check_packages()
# x Package validation failed
# DESCRIPTION Imports not in renv.lock: tidyr
```

**Solution**:

```r
fix_packages()
# Adds tidyr to renv.lock with version from CRAN
```

---
### Scenario 5: Remove Unused Packages

**Use Case**: Clean up packages no longer used in code

**Workflow**:

```r
# Preview what would be removed
sync_packages(dry_run = TRUE)

# Apply changes
sync_packages()

# Or use cleanup flag
check_packages(cleanup = TRUE)
```

---

### Scenario 6: New Collaborator Joins Project

**Use Case**: Validate setup after cloning

**Workflow**:

```r
# Clone the project
# git clone https://github.com/team/project.git

library(zzrenvcheck)

# Validate consistency
check_packages()
# v Package validation passed

# Install packages
renv::restore()
```

---

### Scenario 7: Version Mismatch Across Sources

**Use Case**: DESCRIPTION, `renv.lock`, and a code pin disagree on a
package version

**Workflow**:

```r
library(zzrenvcheck)

# DESCRIPTION: dplyr (>= 2.0.0)
# renv.lock:   dplyr 1.1.0
# code:        pak::pak('dplyr@1.2.0')

check_packages()
# x Found 1 package with inconsistent versions
# ! dplyr: code pin 1.2.0 != renv.lock 1.1.0; renv.lock 1.1.0 violates
#   DESCRIPTION (>= 2.0.0)
```

**Resolution**: reconcile the versions by hand (the check is
report-only). Typically, install the intended version and re-snapshot so
`renv.lock` matches, then align the DESCRIPTION constraint and any code
pin. Inspect the structured detail with:

```r
result <- check_packages()
result$version_conflicts
```

---

## Validation Output Explained

### Success Output

```
v Validation completed successfully
v All packages in code exist in DESCRIPTION
v All Imports/Depends exist in renv.lock
```

**Meaning**: Consistency across code, DESCRIPTION, and renv.lock.

### Warning: Unused Packages

```
! Warning: Packages in renv.lock but not used in code:
  - oldpackage
  - unusedpkg
```

**Meaning**: Packages installed but not imported anywhere. Consider removing.

**Action** (Optional):

```r
sync_packages()  # Removes unused packages
```

### Error: Missing from DESCRIPTION

```
x Package validation failed
Packages used in code but not in DESCRIPTION:
  - ggplot2
  - dplyr
```

**Meaning**: Code uses packages, but DESCRIPTION does not declare dependency.

**Fix**:

```r
fix_packages()
```

### Error: Missing from renv.lock

```
x Package validation failed
DESCRIPTION Imports not in renv.lock:
  - tidyr
  - broom
```

**Meaning**: DESCRIPTION declares packages, but they are not locked.

**Fix**:

```r
fix_packages()
```

---

## Validation Architecture

### Three Sources of Truth

1. **Code Analysis** (R/, scripts/, analysis/, and optionally tests/,
   vignettes/, inst/)
   - Scans for `library()`, `require()`, `package::function()` calls
   - Detects roxygen `@import` and `@importFrom` directives

2. **DESCRIPTION** (Package metadata)
   - Imports: field lists required packages
   - Parsed with `desc` package

3. **renv.lock** (Installed packages)
   - JSON file with exact versions
   - Parsed with `jsonlite` package

### Validation Logic

```
Code Packages ⊆ DESCRIPTION Imports ⊆ renv.lock Packages

If Code uses "dplyr":
  -> DESCRIPTION must Import: dplyr
    -> renv.lock must contain dplyr

Violations = validation failure
```

---

## Strict Mode Differences

### Standard Mode (default)

**Scans**:

- `R/*.R`
- `analysis/scripts/*.R`
- `analysis/report/*.Rmd`

**Use Case**: Daily development, package changes

### Strict Mode

**Scans**:

- Everything in standard mode
- `tests/testthat/*.R`
- `vignettes/*.Rmd`
- `inst/**/*.R`

**Use Case**: Pre-commit checks, CI/CD, release preparation

**Enable**:

```r
check_packages(strict = TRUE)
```

Or shell:

```bash
zzrenvcheck --strict
```

---

## CI/CD Integration

### GitHub Actions Validation

```yaml
# .github/workflows/check-packages.yaml
name: Package Validation

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-r@v2

      - name: Install zzrenvcheck
        run: |
          install.packages("remotes")
          remotes::install_github("rgt47/zzrenvcheck")
        shell: Rscript {0}

      - name: Validate package dependencies
        run: |
          zzrenvcheck::check_packages(strict = TRUE)
        shell: Rscript {0}
```

### Shell Script (No R Installation)

```yaml
# Faster CI/CD without R installation
- name: Install jq
  run: sudo apt-get install -y jq

- name: Validate package dependencies
  run: bash modules/validation.sh --strict
```

---

## Package Source Validation

### Check Where Packages Come From

```r
# Single package
is_installable("dplyr")
# Returns: list(installable = TRUE, source = "CRAN", package = "dplyr")

is_installable("DESeq2")
# Returns: list(installable = TRUE, source = "Bioconductor", package = "DESeq2")

# Batch check
check_installable(c("dplyr", "DESeq2", "NonExistent"))
#   package      installable source
#   dplyr        TRUE        CRAN
#   DESeq2       TRUE        Bioconductor
#   NonExistent  FALSE       NA
```

---

## Shell Script vs R Package

| Feature | Shell Script | R Package |
|---------|--------------|-----------|
| **Requires R** | No | Yes |
| **Platform** | macOS/Linux | Windows/macOS/Linux |
| **CI/CD Speed** | Faster (no R startup) | Slower |
| **Auto-fix** | Yes | Yes |
| **CRAN validation** | Yes | Yes |
| **Bioconductor** | Yes | Yes |
| **GitHub packages** | Yes | Yes |
| **Output format** | Colored terminal | Rich CLI (cli pkg) |

**Recommendations**:

- **R package**: R-based workflows, Windows, RStudio integration
- **Shell script**: CI/CD pipelines, Docker hosts, no R installation

---

## Troubleshooting

### Package Not Found in CRAN

**Symptom**: Fix fails with "Package not found on CRAN"

**Solutions**:

1. Check spelling
2. Package may be on Bioconductor: `is_installable("DESeq2")`
3. Package may be GitHub-only: Add manually to DESCRIPTION

### False Positive: Package Detected But Not Used

**Scenario**: Validation says package used, but you cannot find it

**Solution**:

```r
# Find exact usage
grep -r "library(packagename)" R/ analysis/
```

Common false positives:

- Commented out code
- Strings containing package names
- Package names in documentation

Filtering should handle most cases, but you can check detection:

```r
extract_code_packages()  # See all detected packages
```

### renv.lock Does Not Exist

**Symptom**: Validation fails with "No renv.lock found"

**Solution**:

```r
# Create renv.lock from DESCRIPTION
create_renv_lock()

# Or initialize renv
renv::init()
```

### jq Not Installed (Shell Script)

**Symptom**: `jq: command not found`

**Solution**:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

---

## Best Practices

### 1. Validate Before Committing

```r
check_packages(strict = TRUE)
# Then commit
```

### 2. Use Auto-Fix for Convenience

```r
fix_packages()  # Handles DESCRIPTION and renv.lock
```

### 3. Keep DESCRIPTION Current

When adding packages, validation catches issues immediately.

### 4. Review Validation Output

Do not ignore warnings about unused packages.

### 5. Trust the Validation

If validation passes:

- Code has dependencies declared
- DESCRIPTION has imports listed
- renv.lock has packages locked
- Ready to commit

---

## Quick Decision Tree

```
Need to add package?
|-- Add to code: library(pkg) or pkg::function()
|-- Run: fix_packages()
+-- Commit: git add DESCRIPTION renv.lock

Validation failed?
|-- Missing from DESCRIPTION?
|   +-- Run: fix_packages()
|-- Missing from renv.lock?
|   +-- Run: fix_packages()
+-- Package unused?
    +-- Run: sync_packages()

Want to verify consistency?
|-- Standard check: check_packages()
|-- Strict check: check_packages(strict = TRUE)
+-- Shell: zzrenvcheck --strict

Joining project?
|-- Clone repo: git clone
|-- Validate: check_packages()
+-- Restore: renv::restore()
```

---

## Summary

**Three Commands to Remember**:

1. `check_packages()` - Validate consistency
2. `fix_packages()` - Auto-fix missing packages
3. `sync_packages()` - Sync to code (cleanup unused)

**Key Principle**:

> Code packages ⊆ DESCRIPTION ⊆ renv.lock

**Cross-Platform**:

> R package for Windows; shell script for CI/CD

For comprehensive tutorial, see: `vignettes/quickstart.Rmd`
