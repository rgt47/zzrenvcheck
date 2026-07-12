# Development Guide

This guide covers development commands for working with zzrenvcheck,
including testing, package building, and contribution workflows.

---

## Package Development

### Setup

```bash
# Clone the repository
git clone https://github.com/rgt47/zzrenvcheck.git
cd zzrenvcheck

# Install development dependencies
Rscript -e 'install.packages(c("devtools", "testthat", "roxygen2", "covr"))'
Rscript -e 'devtools::install_deps(dependencies = TRUE)'
```

### Common Commands

```r
# Load package for development
devtools::load_all()

# Run all tests
devtools::test()

# Run specific test file
testthat::test_file("tests/testthat/test-check_packages.R")

# Generate documentation
devtools::document()

# Check package
devtools::check()

# Build package
devtools::build()
```

### Makefile Targets

```bash
# Run tests
make test

# Check package (R CMD check)
make check

# Generate documentation
make document

# Build package
make build

# Install locally
make install

# Clean build artifacts
make clean
```

---

## Testing

### Test Suite Overview

zzrenvcheck has a comprehensive test suite with 101 tests:

```
tests/
+-- testthat/
    +-- test-check_packages.R      # Main validation tests
    +-- test-extract_code.R        # Package extraction tests
    +-- test-clean_names.R         # Filter tests (19 filters)
    +-- test-parse_description.R   # DESCRIPTION parsing tests
    +-- test-parse_renv_lock.R     # renv.lock parsing tests
    +-- test-is_installable.R      # CRAN/Bioconductor validation
    +-- test-fix_packages.R        # Auto-fix tests
    +-- test-sync_packages.R       # Sync to code tests
    +-- helper-functions.R         # Test utilities
```

### Running Tests

```r
# All tests
devtools::test()

# Specific test file
testthat::test_file("tests/testthat/test-check_packages.R")

# Tests matching pattern
devtools::test(filter = "extract")

# With coverage
covr::package_coverage()
```

### Test Patterns

**Unit Test Structure**:

```r
test_that("function handles expected input", {
    # Arrange
    input <- create_test_data()

    # Act
    result <- function_under_test(input)

    # Assert
    expect_equal(result$status, "pass")
    expect_length(result$packages, 3)
})
```

**Testing with Temporary Directories**:

```r
test_that("check_packages works in project directory", {
    # Create temporary project
    temp_dir <- tempfile()
    dir.create(temp_dir)
    on.exit(unlink(temp_dir, recursive = TRUE))

    # Create test files
    writeLines('library(dplyr)', file.path(temp_dir, "R", "analysis.R"))
    writeLines('Package: testpkg', file.path(temp_dir, "DESCRIPTION"))

    # Test
    withr::with_dir(temp_dir, {
        result <- check_packages(auto_fix = FALSE)
        expect_equal(result$status, "fail")
    })
})
```

### Coverage Requirements

- Target: >90% code coverage
- Current: 85%+ (run `covr::package_coverage()` to check)

---

## Shell Script Development

### Testing Shell Script

```bash
# Validate syntax
bash -n modules/validation.sh

# Run with verbose output
bash modules/validation.sh --verbose

# Test strict mode
bash modules/validation.sh --strict

# Test auto-fix
bash modules/validation.sh --fix --verbose
```

### Shell Test Suite

```bash
# Run shell tests
make shell-test

# Individual test files
bash tests/shell/test-validation.sh
```

### Shell Coding Standards

- Use `shellcheck` for linting
- Quote all variables: `"$var"`
- Use `[[ ]]` for conditionals
- Prefer `local` for function variables
- Add function documentation headers

---

## Documentation

### Generating Documentation

```r
# Generate man pages from roxygen2
devtools::document()

# Build vignettes
devtools::build_vignettes()

# Preview README
devtools::build_readme()
```

### Documentation Standards

**Roxygen2 Template**:

```r
#' Function Title
#'
#' Longer description of what the function does.
#'
#' @param path Character. Path to project directory.
#' @param strict Logical. Include tests/ and vignettes/ directories.
#' @param verbose Logical. Print detailed output.
#'
#' @return A list with components:
#'   - `status`: "pass" or "fail"
#'   - `packages`: Character vector of packages
#'
#' @export
#'
#' @examples
#' \dontrun{
#' check_packages()
#' check_packages(strict = TRUE)
#' }
function_name <- function(path = ".", strict = FALSE, verbose = TRUE) {
    # Implementation
}
```

### Markdown Documentation

Documentation files in `docs/`:

| File | Purpose |
|------|---------|
| `validation-quick-reference.md` | Quick command reference |
| `validation-architecture.md` | Technical architecture |
| `development.md` | This guide |
| `data-workflow-guide.md` | Data analysis workflows |

---

## Validation Workflow

### Core Validation

The validation system checks three sources:

1. **Code Analysis**: Scan R files for package usage
2. **DESCRIPTION**: Parse Imports/Depends fields
3. **renv.lock**: Parse locked package versions

```r
# Get packages from each source
code_pkgs <- extract_code_packages()
desc_pkgs <- parse_description_imports()
renv_pkgs <- parse_renv_lock()

# Validate consistency
missing_desc <- setdiff(code_pkgs, desc_pkgs)
missing_renv <- setdiff(desc_pkgs, renv_pkgs)
```

### Auto-Fix Pipeline

```r
# Check CRAN
if (is_on_cran(package)) {
    version <- get_cran_version(package)
    add_to_description(package)
    add_to_renv_lock(package, version, "CRAN")
}

# Check Bioconductor
if (is_on_bioconductor(package)) {
    version <- get_bioc_version(package)
    add_to_description(package)
    add_to_renv_lock(package, version, "Bioconductor")
}
```

### Filtering (19 Filters)

```r
# Base R packages
base_pkgs <- c("base", "utils", "stats", "graphics", "grDevices",
               "methods", "datasets", "tools", "grid", "parallel")

# Placeholders
placeholders <- c("myproject", "package", "pkg", "foo", "bar",
                  "example", "test", "demo", "sample", "temp")

# Generic words
generic <- c("my", "your", "file", "path", "data", "code")
```

---

## CI/CD

### GitHub Actions Workflow

The package uses GitHub Actions for CI:

```yaml
# .github/workflows/R-CMD-check.yaml
name: R-CMD-check

on: [push, pull_request]

jobs:
  R-CMD-check:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        r-version: ['4.3', '4.4']

    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: ${{ matrix.r-version }}

      - uses: r-lib/actions/setup-r-dependencies@v2

      - uses: r-lib/actions/check-r-package@v2
```

### Local CI Simulation

```bash
# Run what CI runs
Rscript -e 'rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")'
```

---

## Contributing

### Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Make changes
4. Add tests
5. Run `devtools::check()`
6. Submit pull request

### Code Style

- Use `<-` for assignment
- Use `|>` (native pipe, not `%>%`)
- Use `snake_case` for function names
- No explicit `return()` for final expressions
- Keep functions under 50 lines when possible

### Pull Request Checklist

- [ ] Tests pass: `devtools::test()`
- [ ] Check passes: `devtools::check()`
- [ ] Documentation updated: `devtools::document()`
- [ ] NEWS.md updated (for user-facing changes)
- [ ] DESCRIPTION version bumped (for releases)

---

## Release Process

### Version Numbering

- `0.1.0` - Initial release
- `0.1.1` - Patch (bug fixes)
- `0.2.0` - Minor (new features, backward compatible)
- `1.0.0` - Major (breaking changes)

### Release Checklist

1. Update version in DESCRIPTION
2. Update NEWS.md
3. Run full check: `devtools::check()`
4. Build package: `devtools::build()`
5. Tag release: `git tag v0.2.0`
6. Push: `git push origin v0.2.0`

---

## Debugging

### Common Issues

**Package detection missing library() calls**:

```r
# Check regex patterns
content <- readLines("R/analysis.R")
matches <- stringr::str_match_all(content, "library\\s*\\(\\s*[\"']?([a-zA-Z][a-zA-Z0-9._]+)")
```

**False positives not filtered**:

```r
# Check filter list
packages <- c("dplyr", "myproject", "foo")
clean_package_names(packages)
# Should return: "dplyr"
```

**CRAN API timeout**:

```r
# Increase timeout
options(zzrenvcheck.timeout = 10)
is_installable("dplyr")
```

### Verbose Debugging

```r
# Enable verbose output
check_packages(verbose = TRUE)

# Or set globally
options(zzrenvcheck.verbose = TRUE)
```

---

## Related Documentation

- **Quick Reference**: `docs/validation-quick-reference.md`
- **Architecture**: `docs/validation-architecture.md`
- **Vignette**: `vignettes/quickstart.Rmd`
- **README**: `README.md`

---

## Package Dependencies

### Runtime Dependencies

| Package | Purpose |
|---------|---------|
| `desc` | DESCRIPTION file manipulation |
| `jsonlite` | renv.lock JSON parsing |
| `httr` | HTTP requests for API validation |
| `cli` | Rich CLI output |

### Development Dependencies

| Package | Purpose |
|---------|---------|
| `testthat` | Testing framework |
| `withr` | Test isolation |
| `devtools` | Package development |
| `roxygen2` | Documentation generation |
| `covr` | Code coverage |
