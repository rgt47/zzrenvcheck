# Extract requireNamespace() and loadNamespace() Calls

These are the standard idioms for using an optional dependency, the form
CRAN expects for anything in `Suggests`. They were not recognised:
[`requireNamespace("pkg")`](https://rdrr.io/r/base/ns-load.html) matched
neither the `require(` pattern, because `requireNamespace` is not
followed by a parenthesis at that point, nor the `::` pattern. A package
used only through this idiom was reported as undeclared nowhere and
silently omitted from the dependency set.

## Usage

``` r
extract_namespace_load_calls(lines)
```

## Arguments

- lines:

  Character vector of file lines.

## Value

Character vector of package names.
