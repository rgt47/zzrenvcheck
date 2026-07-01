# Detect Cross-Document Version Conflicts

Compares the versions recorded for each package across DESCRIPTION
constraints, renv.lock exact versions, and exact pins drawn from code
and the DESCRIPTION `Remotes:` field, applying constraint-aware rules. A
package is reported when any of the following holds:

1.  two pins for the package disagree (across or within sources);

2.  a pin differs from the renv.lock version;

3.  the renv.lock version violates the DESCRIPTION constraint;

4.  a pin violates the DESCRIPTION constraint.

Packages with no version data to compare, or whose only constraint is
`"*"`, never appear.

## Usage

``` r
detect_version_conflicts(desc_deps, lock_versions, code_versions)
```

## Arguments

- desc_deps:

  Data frame from
  [`parse_description_all_deps()`](https://rgt47.github.io/zzrenvcheck/reference/parse_description_all_deps.md)
  with columns `package`, `type`, `version`.

- lock_versions:

  Data frame from
  [`parse_renv_lock_versions()`](https://rgt47.github.io/zzrenvcheck/reference/parse_renv_lock_versions.md)
  with columns `package`, `version`.

- code_versions:

  Data frame of exact pins with columns `package`, `version`, and
  optionally `source` (a label such as `"code"` or
  `"DESCRIPTION Remotes"`). When `source` is absent every pin is
  labelled `"code"`.

## Value

Data frame with columns `package`, `description`, `lock`, `code`, and
`issue`; zero rows when no conflicts are found.
