# Clean and Validate Package Names

Applies 19 filters to remove invalid package names, base packages,
placeholders, and generic words that are false positives.

## Usage

``` r
clean_package_names(packages)
```

## Arguments

- packages:

  Character vector of raw package names (may include duplicates).

## Value

Character vector of validated package names (sorted, deduplicated)

## Details

Validation rules applied:

- Minimum 3 characters (R package requirement)

- Must start with a letter (a-zA-Z)

- Can contain letters, numbers, and dots only

- Cannot start or end with a dot

- Excludes base R packages

- Excludes placeholder names

- Excludes generic English words

## Examples

``` r
packages <- c("dplyr", "base", "ggplot2", "my", ".invalid", "dplyr")
clean_package_names(packages)
#> [1] "dplyr"   "ggplot2"
# Returns: c("dplyr", "ggplot2")
```
