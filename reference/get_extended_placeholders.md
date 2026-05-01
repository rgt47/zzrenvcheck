# Add Current Package to Placeholders

Dynamically adds the current package name to the placeholder list to
prevent self-referencing in DESCRIPTION.

## Usage

``` r
get_extended_placeholders(path = ".")
```

## Arguments

- path:

  Character. Path to project root.

## Value

Character vector. Updated PLACEHOLDER_PACKAGES.
