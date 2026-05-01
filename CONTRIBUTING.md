# Contributing to zzrenvcheck

Thank you for your interest in contributing. This document describes the
expected workflow for proposing changes, reporting issues, and
submitting pull requests.

zzrenvcheck ships two parallel implementations:

- An R package (`R/`, exposing
  [`check_packages()`](https://rgt47.github.io/zzrenvcheck/reference/check_packages.md)
  and friends).
- A standalone POSIX shell script (`modules/validation.sh`, installable
  via `install.sh`).

Both use the same validation logic. When you change validation
behaviour, please update both in the same pull request so they do not
drift.

## Reporting issues

Before opening an issue, please search existing issues at
<https://github.com/rgt47/zzrenvcheck/issues> to confirm the problem has
not already been reported. When opening a new issue, include:

- A minimal reproducible example (a `reprex::reprex()` for R, a copy of
  the project structure and command for the shell script).
- The output of
  [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) (R) or
  `bash --version` and the OS version (shell).
- The version of zzrenvcheck in use.
- The expected behaviour and the observed behaviour.

## Pull request workflow

1.  Fork the repository and create a topic branch off `main`.

2.  Install development dependencies:

    ``` r

    renv::restore()
    ```

3.  Make your changes.

    - For R changes, update both the function and its `roxygen2` block.
    - For shell changes, update `modules/validation.sh` and ensure POSIX
      compatibility (no bashisms).

4.  Add or update tests in `tests/testthat/`. The R test suite covers
    parsing, extraction, and CRAN/Bioconductor/GitHub validation.

5.  Run `devtools::document()` to regenerate `man/` and `NAMESPACE`.

6.  Run the full check locally:

    ``` r

    devtools::check()
    ```

7.  For shell-script changes, run `shellcheck modules/validation.sh` and
    verify on the supported targets.

8.  Update `NEWS.md` with a one-line bullet under the unreleased
    section.

9.  Open a pull request against `main`. Reference any related issues.

## Coding style

### R code

- Use the native R pipe (`|>`); avoid `%>%` in new code.
- Use `<-` for assignment, never `=`.
- Use `snake_case` for functions and variables.
- Prefer implicit returns; reserve
  [`return()`](https://rdrr.io/r/base/function.html) for early exits.
- Document all exported functions with `roxygen2`. Each must have
  `@title`, `@description`, `@param`, `@return`, and `@examples`.
- Two-space indentation. Single quotes for character literals.

### Shell script

- POSIX-compatible (`#!/usr/bin/env bash` only when justified).
- `shellcheck` must pass.
- Two-space indentation, snake_case variables.
- Quote all variable expansions.

## Tests

``` r

devtools::test()
```

For coverage:

``` r

covr::package_coverage()
```

## Code of Conduct

By participating in this project, you agree to abide by the [Code of
Conduct](https://rgt47.github.io/zzrenvcheck/CODE_OF_CONDUCT.md).
