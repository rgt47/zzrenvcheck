# Reproducibility Files Scanned for Version Pins

Non-R project files that commonly carry version-pinned install commands
and can therefore drift from `renv.lock`. These are scanned by
[`extract_code_package_versions()`](https://rgt47.github.io/zzrenvcheck/reference/extract_code_package_versions.md)
only (the version-synchronisation check); they are deliberately excluded
from the plain package-name scan, where build tooling and shell commands
would generate false positives.

## Usage

``` r
REPRO_FILES
```
