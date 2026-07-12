# Testing Guide

## Overview

zzrenvcheck is tested with `tinytest`. This guide documents the test
layout, the conventions used in the suite, and how to run and extend it.
The unit suite is the authoritative test surface and is executed by
`R CMD check`; a separate set of `testthat`-based integration scripts
exercises full analysis pipelines and is run manually.

---

## Testing Philosophy

### Goals

1. **Correctness**: validation detects the dependencies actually used.
2. **Reliability**: consistent behaviour across platforms and offline.
3. **Coverage**: exercise code paths and edge cases, not just the happy
   path.
4. **Maintainability**: tests double as executable documentation.

### Coverage targets

| Component | Target |
|-----------|--------|
| Core validation | > 95% |
| Package extraction | > 90% |
| Filtering | > 95% |
| Parsing | > 90% |
| Overall | > 90% |

Measure the current figure with `covr` (see Coverage Analysis below)
rather than quoting a fixed number here.

---

## Test Architecture

### Test Structure

Unit tests use `tinytest` and live in `inst/tinytest/`. The runner
`tests/tinytest.R` dispatches them, so they run under `R CMD check`.

```
tests/
+-- tinytest.R                     # Runner: tinytest::test_package()
+-- integration/                   # testthat + here, run manually
    +-- test-analysis-scripts.R    # Analysis scripts execute
    +-- test-data-pipeline.R       # Data pipeline end to end
    +-- test-report-rendering.R    # Report rendering

inst/tinytest/
+-- test_clean.R          # Filter system            (42 assertions)
+-- test_extract.R        # Package extraction        (18 assertions)
+-- test_parse.R          # DESCRIPTION/renv.lock      (7 assertions)
+-- test_sync.R           # Sync to code              (37 assertions)
+-- test_utils.R          # Utilities                  (1 assertion)
+-- test_validate.R       # Source validation (network-gated, 19)
+-- test_version_sync.R   # Version synchronization   (52 assertions)
```

Counts are the assertions present in each file. Network-gated
assertions in `test_validate.R` are skipped when no CRAN mirror is
configured (for example under `R CMD check`), so the executed count is
lower than the static total.

### Running Tests

`tinytest` is the framework; `devtools::test()` is **not** wired for
this package and reports "No testing infrastructure found". Use one of:

```r
# Full package suite (installed or via R CMD check semantics)
tinytest::test_package('zzrenvcheck')

# During development, against the loaded source
pkgload::load_all('.')
tinytest::run_test_dir('inst/tinytest')

# A single file
pkgload::load_all('.')
tinytest::run_test_file('inst/tinytest/test_version_sync.R')
```

From the shell:

```bash
Rscript -e 'tinytest::test_package("zzrenvcheck")'
```

---

## Unit Testing

### Conventions

A `tinytest` file is a script of top-level `expect_*()` calls. The suite
groups related assertions in a `local({ ... })` block introduced by a
one-line `#` comment naming the behaviour, and labels each assertion
with `info=`. Each block creates and cleans up its own temporary
project; there is no shared helper file.

```r
# clean_package_names removes base packages and placeholders
local({
  input <- c('dplyr', 'base', 'myproject', 'ggplot2')
  result <- clean_package_names(input)
  expect_true('dplyr' %in% result, info = 'real package kept')
  expect_false('base' %in% result, info = 'base package dropped')
  expect_false('myproject' %in% result, info = 'placeholder dropped')
})
```

Assertions used across the suite: `expect_equal`, `expect_true`,
`expect_false`, `expect_identical`, `expect_inherits`, and
`expect_error`. Internal (unexported) functions are reached with the
`zzrenvcheck:::` prefix.

### Package Extraction Tests

Functions take an explicit `path=` (and `dirs=`) argument, so tests
point them at a temporary directory rather than changing the working
directory.

```r
# extract_code_packages detects library(), namespace, and roxygen
local({
  d <- tempfile()
  dir.create(file.path(d, 'R'), recursive = TRUE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  writeLines(c(
    'library(dplyr)',
    'ggplot2::ggplot()',
    "#' @importFrom tidyr pivot_longer"
  ), file.path(d, 'R', 'a.R'))
  pkgs <- extract_code_packages(dirs = 'R', path = d)
  expect_true('dplyr' %in% pkgs, info = 'library call')
  expect_true('ggplot2' %in% pkgs, info = 'namespace call')
  expect_true('tidyr' %in% pkgs, info = 'roxygen import')
})
```

### DESCRIPTION and renv.lock Parsing Tests

```r
# parse_description_imports extracts the Imports field
local({
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  writeLines(c(
    'Package: testpkg',
    'Imports:',
    '    dplyr (>= 1.0.0),',
    '    tidyr'
  ), file.path(d, 'DESCRIPTION'))
  result <- parse_description_imports(path = d)
  expect_true('dplyr' %in% result, info = 'constrained import')
  expect_true('tidyr' %in% result, info = 'plain import')
})

# parse_renv_lock_versions returns package and version columns
local({
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  writeLines(c(
    '{"R":{"Version":"4.4.0"},"Packages":{',
    '  "dplyr":{"Package":"dplyr","Version":"1.1.0"}}}'
  ), file.path(d, 'renv.lock'))
  res <- zzrenvcheck:::parse_renv_lock_versions(d)
  expect_equal(res$version[res$package == 'dplyr'], '1.1.0',
               info = 'lock version captured')
})
```

### Version Synchronization Tests

`test_version_sync.R` covers the version-consistency check: the
constraint operator semantics of `version_satisfies()`, every install
pin grammar handled by `extract_code_package_versions()` (pak and renv
`@`-syntax, vectors and multi-argument calls, the argument shapes of
`install_version()`, and reproducibility-file scanning),
`parse_description_remotes()`, and each conflict rule in
`detect_version_conflicts()`.

```r
# detect_version_conflicts flags a lock version that violates DESCRIPTION
local({
  desc <- data.frame(package = 'dplyr', type = 'Imports',
                     version = '>= 2.0.0', stringsAsFactors = FALSE)
  lock <- data.frame(package = 'dplyr', version = '1.1.0',
                     stringsAsFactors = FALSE)
  code <- data.frame(package = character(0), version = character(0),
                     stringsAsFactors = FALSE)
  res <- zzrenvcheck:::detect_version_conflicts(desc, lock, code)
  expect_equal(nrow(res), 1, info = 'violation flagged')
  expect_true(grepl('violates', res$issue), info = 'issue names violation')
})

# check_packages(error_on_fail = TRUE) raises a classed condition
local({
  d <- tempfile()
  dir.create(file.path(d, 'R'), recursive = TRUE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  writeLines(c('Package: smoke', 'Version: 0.1.0',
               'Imports:', '    dplyr (>= 2.0.0)'),
             file.path(d, 'DESCRIPTION'))
  writeLines(
    '{"R":{"Version":"4.4.0"},"Packages":{"dplyr":{"Package":"dplyr","Version":"1.1.0"}}}',
    file.path(d, 'renv.lock'))
  err <- tryCatch(
    suppressMessages(check_packages(path = d, verbose = FALSE,
                                    error_on_fail = TRUE)),
    zzrenvcheck_validation_failure = function(e) e
  )
  expect_true(inherits(err, 'zzrenvcheck_validation_failure'),
              info = 'failure raises classed condition')
})
```

### Integration Workflow Tests

```r
# check_packages reports a package used in code but not declared
local({
  d <- tempfile()
  dir.create(file.path(d, 'R'), recursive = TRUE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  writeLines('library(dplyr)', file.path(d, 'R', 'analysis.R'))
  writeLines(c('Package: testpkg', 'Imports:', '    ggplot2'),
             file.path(d, 'DESCRIPTION'))
  writeLines('{"Packages":{}}', file.path(d, 'renv.lock'))
  result <- suppressMessages(
    check_packages(path = d, auto_fix = FALSE, verbose = FALSE)
  )
  expect_equal(result$status, 'fail', info = 'inconsistent project fails')
  expect_true('dplyr' %in% result$missing_in_description,
              info = 'dplyr reported missing')
})
```

---

## Network Tests

Source-validation tests hit CRAN, Bioconductor, and GitHub, so they are
guarded and skipped unless a real CRAN mirror is configured. The suite
computes a single predicate and gates network blocks on it, so
`R CMD check` (which sets `NOT_CRAN=true` but leaves `repos` at
`@CRAN@`) does not error.

```r
not_on_cran <- identical(Sys.getenv('NOT_CRAN'), 'true') &&
  !is.null(getOption('repos')[['CRAN']]) &&
  nzchar(getOption('repos')[['CRAN']]) &&
  !identical(unname(getOption('repos')[['CRAN']]), '@CRAN@')

# is_installable finds CRAN packages
if (not_on_cran) local({
  result <- is_installable('jsonlite', check_bioc = FALSE,
                           check_github = FALSE)
  expect_true(result$installable, info = 'jsonlite installable')
  expect_equal(result$source, 'CRAN', info = 'source is CRAN')
})
```

Structural assertions that do not need the network (return type, column
names, empty-input handling) run unconditionally.

---

## Shell Script Tests

The shell validator `modules/validation.sh` has no automated test suite.
It is checked two ways:

1. Static analysis with `shellcheck modules/validation.sh`, which must
   pass.
2. Manual exercise by sourcing the module and calling functions against
   a temporary project, for example:

   ```bash
   source modules/validation.sh
   cd /path/to/temp/project
   check_version_conflicts false true
   ```

Because the shell logic mirrors the R paths, the tinytest suite is the
primary guard against behavioural regressions; a shell change should be
confirmed to produce output matching its R counterpart on the same
input.

---

## Coverage Analysis

```r
# Whole-package coverage using the tinytest suite
cov <- covr::package_coverage()
print(cov)
covr::report(cov)   # HTML report

# Focus on the version-synchronization surface
cov <- covr::file_coverage(
  source_files = c('R/compare.R', 'R/extract.R', 'R/parse.R'),
  test_files = 'inst/tinytest/test_version_sync.R'
)
```

---

## Best Practices

### General Principles

1. **Test behaviour, not implementation**: assert on inputs and outputs.
2. **Label every assertion**: pass `info=` so failures are diagnosable.
3. **Independent blocks**: each `local({})` sets up and tears down its
   own temporary project.
4. **Deterministic and offline by default**: gate network access behind
   `not_on_cran`.
5. **Clear names**: the `#` comment above a block states the scenario.

### Handling Edge Cases

```r
# clean_package_names handles empty, single, all-filtered, and NA input
local({
  expect_equal(length(clean_package_names(character(0))), 0,
               info = 'empty input')
  expect_equal(length(clean_package_names('dplyr')), 1,
               info = 'single element')
  expect_equal(length(clean_package_names(c('base', 'utils'))), 0,
               info = 'all filtered')
  expect_false(any(is.na(clean_package_names(c('dplyr', NA)))),
               info = 'NA dropped')
})
```

---

## Troubleshooting

### Tests pass locally but fail in check or CI

1. Confirm the failing block is not network-dependent; if it is, it
   should sit behind `not_on_cran`.
2. Check for absolute or platform-specific paths; use `tempfile()` and
   `file.path()`.
3. Confirm the package is loaded (`pkgload::load_all('.')`) before
   `run_test_dir()` during development.

### A file scan skips files unexpectedly

`filter_skip_paths()` skips a file when a path *segment* matches an
entry in `SKIP_DIRS` (for example a `renv/` directory). Ensure test
fixtures do not place source files under such a segment unless that is
the behaviour under test.

---

## References

- tinytest: https://github.com/markvanderloo/tinytest
- Writing R Extensions (Checking and building):
  https://cran.r-project.org/doc/manuals/r-release/R-exts.html
- covr: https://covr.r-lib.org/
