# Fetch Bioconductor Package Information

Queries the Bioconductor API for package metadata.

## Usage

``` r
fetch_bioc_info(package, version = "3.19")
```

## Arguments

- package:

  Character. Package name.

- version:

  Character. Bioconductor version. Default: "3.19".

## Value

List with package information, or NULL if not found
