# Pick a DESCRIPTION Version Constraint for a Package

Returns the most informative constraint recorded for a package across
dependency types, preferring an explicit constraint over the wildcard
`"*"`.

## Usage

``` r
desc_constraint_for(desc_deps, pkg)
```

## Arguments

- desc_deps:

  Data frame with columns `package`, `version`.

- pkg:

  Character. Package name.

## Value

Character scalar constraint, or `NA_character_` when the package is not
declared.
