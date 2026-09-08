# Blank String Literals and Trailing Comments

Replaces the contents of quoted spans with spaces and removes
end-of-line comments, so that patterns which cannot legitimately appear
inside a string (namespaced calls) are not matched there. Quoting state
is tracked per line; a `#` inside a string does not start a comment. A
string spanning several lines is not tracked across the break, which is
rare in R source and errs toward keeping code rather than dropping it.

## Usage

``` r
mask_strings_and_comments(lines)
```

## Arguments

- lines:

  Character vector of file lines.

## Value

Character vector the same length as `lines`.
