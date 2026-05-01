# Validate Package Name Format

Checks if package name follows R package naming rules:

- Starts with a letter

- Contains only letters, numbers, and dots

- Does not start or end with a dot

## Usage

``` r
is_valid_package_name(pkg)
```

## Arguments

- pkg:

  Character. Package name to validate.

## Value

Logical. TRUE if valid, FALSE otherwise.
