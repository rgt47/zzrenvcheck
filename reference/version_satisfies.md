# Test Whether a Version Satisfies a Constraint

Compares an exact version string against a DESCRIPTION-style version
constraint (e.g. `">= 1.0.0"`). An absent constraint (`"*"`, empty, or
`NA`) is satisfied by any version. Unparseable constraints are treated
as satisfied so that non-standard version strings never produce spurious
conflicts.

## Usage

``` r
version_satisfies(version, constraint)
```

## Arguments

- version:

  Character. Exact version, e.g. `"1.1.0"`.

- constraint:

  Character. Constraint such as `">= 1.0.0"` or `"*"`.

## Value

Logical scalar. `TRUE` if the constraint is satisfied.
