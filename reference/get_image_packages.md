# Query Packages Installed in a Docker Image

Runs a one-shot container from the named image and returns the names of
all R packages found in the site and base libraries (i.e. everything
baked in at build time outside of the renv project library). Used by
[`check_packages`](https://rgt47.github.io/zzrenvcheck/reference/check_packages.md)
when `skip_image_pkgs = TRUE` to avoid adding image-resident packages to
`renv.lock`.

## Usage

``` r
get_image_packages(
  image = basename(getwd()),
  runtime = "docker",
  lib_paths = c("/usr/local/lib/R/site-library", "/usr/local/lib/R/library")
)
```

## Arguments

- image:

  Character. Docker image name or tag. Defaults to `basename(getwd())`,
  which matches the zzcollab `PACKAGE_NAME` Makefile variable.

- runtime:

  Character. Container runtime binary. Default: `"docker"`.

- lib_paths:

  Character vector. Library paths to query inside the container. Default
  covers the rocker site-library and base library.

## Value

Character vector of package names, or `character(0)` if the image is not
found or the query fails.
