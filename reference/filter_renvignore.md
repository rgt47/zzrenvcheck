# Filter Files Against .renvignore Patterns

Drops files whose project-relative path matches any `.renvignore`
pattern. Supports a gitignore-lite subset: bare filenames, exact
relative paths, glob patterns, and directory/path substrings (enough for
the common exclusions; renv itself applies full gitignore semantics).

## Usage

``` r
filter_renvignore(files, path)
```

## Arguments

- files:

  Character vector of absolute file paths.

- path:

  Character. Project root.

## Value

Filtered character vector.
