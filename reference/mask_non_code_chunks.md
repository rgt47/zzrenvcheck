# Mask Non-Code Lines in R Markdown / Quarto

For `.Rmd`/`.qmd`/`.Rmarkdown` files, blanks every line that is not
inside a fenced R code chunk, keeping inline R code spans in prose
lines. Non-Rmd files pass through unchanged. This prevents package
references in markdown or LaTeX prose (for example a namespaced call
written inside \texttt in a methods description, or install
instructions) from being counted as code dependencies.

## Usage

``` r
mask_non_code_chunks(lines, file)
```

## Arguments

- lines:

  Character vector of file lines.

- file:

  Character. File path (used only for its extension).

## Value

Character vector the same length as `lines`; non-code lines are empty
strings.
