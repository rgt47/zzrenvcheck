# Code Version-Pin Install Forms

Patterns used by
[`extract_code_package_versions()`](https://rgt47.github.io/zzrenvcheck/reference/extract_code_package_versions.md)
to recognise version-pinned package installs. Two grammars are
supported:

- `@`-syntax: `pak::pak('dplyr@1.1.0')`, `pak('dplyr@1.1.0')`,
  `pak::pkg_install('dplyr@1.1.0')`, `renv::install('dplyr@1.1.0')`.

- `version=` syntax:
  `remotes::install_version('dplyr', version = '1.1.0')`,
  `devtools::install_version('dplyr', version = '1.1.0')`.

For the `@`-syntax, `pin_call_at` detects that a line contains such an
install call and `at_token` then extracts every `'pkg@version'` token on
that line, so vectorised (`pak(c('a@1', 'b@2'))`) and multi-argument
calls are all captured. The version token must begin with a digit, which
excludes GitHub refs (`owner/repo@branch`).

## Usage

``` r
CODE_PIN_PATTERNS
```
