# Parse the Project's Own Package Name

Reads the `Package:` field from DESCRIPTION. Analysis reports often call
`library(<own_pkg>)` to load the workspace package itself; that
self-reference must never be treated as a missing dependency, as a
package cannot import itself.

## Usage

``` r
parse_description_package_name(path = ".")
```

## Arguments

- path:

  Character. Path to project root.

## Value

Character scalar package name, or `character(0)` if the field is absent
or unreadable.
