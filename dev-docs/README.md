# zzrenvcheck Documentation

This directory contains documentation for the zzrenvcheck package.

## Quick Start

- **[README](../README.md)** - Package overview and installation
- **[Quickstart Vignette](../vignettes/quickstart.Rmd)** - Getting started guide

## Motivation

| Document | Description |
|----------|-------------|
| [motivation/reproducibility-crisis.md](motivation/reproducibility-crisis.md) | The R reproducibility crisis and why validation matters |

## Core Documentation

| Document | Description |
|----------|-------------|
| [validation-quick-reference.md](validation-quick-reference.md) | Quick command reference for validation |
| [validation-architecture.md](validation-architecture.md) | Technical architecture and design |
| [development.md](development.md) | Development and contribution guide |
| [testing-guide.md](testing-guide.md) | Testing patterns and best practices |

## Workflow Guides

| Document | Description |
|----------|-------------|
| [data-workflow-guide.md](data-workflow-guide.md) | Data analysis workflows |
| [zzcollab-user-guide.md](zzcollab-user-guide.md) | Integration with zzcollab |

## For Users

### Validation Commands

**R Package**:

```r
library(zzrenvcheck)
check_packages()     # Validate
fix_packages()       # Auto-fix
sync_packages()      # Sync to code
```

**Shell Script** (no R required):

```bash
zzrenvcheck --fix --strict --verbose
```

### Common Workflows

1. **Check project dependencies**: `check_packages()`
2. **Fix missing packages**: `fix_packages()`
3. **Clean up unused**: `sync_packages()`
4. **Generate report**: `report_packages()`

## For Developers

### Development Setup

```bash
git clone https://github.com/rgt47/zzrenvcheck.git
cd zzrenvcheck
Rscript -e 'devtools::install_deps(dependencies = TRUE)'
Rscript -e 'devtools::test()'
```

### Key Files

| File | Purpose |
|------|---------|
| `R/check_packages.R` | Main validation logic |
| `R/extract_code_packages.R` | Package detection |
| `R/clean_package_names.R` | 19 filters |
| `R/parse_description.R` | DESCRIPTION parsing |
| `R/parse_renv_lock.R` | renv.lock parsing |
| `R/is_installable.R` | CRAN/Bioconductor validation |
| `modules/validation.sh` | Shell script version |

### Testing

```r
devtools::test()                  # Run all tests
covr::package_coverage()          # Coverage report
```

## Related Projects

- **[zzcollab](https://github.com/rgt47/zzcollab)** - Docker-based reproducible
  research framework
- **[renv](https://rstudio.github.io/renv/)** - R package dependency management

## Document Versions

| Document | Last Updated |
|----------|--------------|
| validation-quick-reference.md | January 2025 |
| validation-architecture.md | January 2025 |
| development.md | January 2025 |
| testing-guide.md | January 2025 |
