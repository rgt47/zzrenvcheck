# Add Package to renv.lock

Adds a package entry to renv.lock. When `version` is NULL, the entry
records the version installed in the current library (see
[`installed_lock_entry()`](https://rgt47.github.io/zzrenvcheck/reference/installed_lock_entry.md)),
so the lockfile matches the environment the code was run in. Only when
the package is not installed does it fall back to the current CRAN
version, and it says so.

## Usage

``` r
add_to_renv_lock(package, version = NULL, path = ".", lib.loc = NULL)
```

## Arguments

- package:

  Character. Package name.

- version:

  Character. Package version. If NULL, the installed version is used,
  falling back to the current CRAN version when the package is not
  installed.

- path:

  Character. Path to project root.

- lib.loc:

  Character vector of library paths searched for the installed package,
  or NULL for [`.libPaths()`](https://rdrr.io/r/base/libPaths.html).

## Value

Logical indicating success
