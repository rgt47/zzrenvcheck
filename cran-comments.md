## Submission summary

This is a new submission. zzrenvcheck validates that the R packages used in
a project's source code are declared in DESCRIPTION and locked in renv.lock,
to support reproducible research environments.

## Test environments

* Local: macOS Tahoe 26.6.2 (aarch64-apple-darwin23), R 4.6.0,
  `R CMD check --as-cran --no-manual` on 2026-11-16

Before submission this should also be checked on:

* win-builder (devel and release)
* R-hub (a Linux and a Windows target)

## R CMD check results

0 errors | 0 warnings | 1 note

The note is:

```
* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Ronald G. Thomas <rgthomas@ucsd.edu>'
  New submission
```

This note is expected for a first-time submission.

A second note may appear on some local machines, 'checking HTML version of
manual ... NOTE: tidy doesn't look like recent enough HTML Tidy'. It
reflects an outdated HTML Tidy binary on the checking machine (for example
the version Apple bundles with macOS), not the package, and does not occur
on the CRAN check machines.

Note to maintainer (2026-11-16): the committed 0.10.0 tree failed this
check with 1 WARNING (codoc mismatch: `skip_image_pkgs` and `image`
undocumented in `check_packages.Rd` and `sync_packages.Rd`) because
`man/` had not been regenerated. After `devtools::document()`, the
local run above gives 0 errors, 0 warnings, and the single 'New
submission' note. The manual (PDF) was not checked locally
(`--no-manual`); re-run without that flag, and on win-builder and
R-hub, before submission.

## Reverse dependencies

None. This is a new package with no reverse dependencies.
