## Submission summary

This is a new submission. zzrenvcheck validates that the R packages used in
a project's source code are declared in DESCRIPTION and locked in renv.lock,
to support reproducible research environments.

## Test environments

* Local: macOS 15 (aarch64-apple-darwin25.4.0), R 4.6.0

Before submission this should also be checked on:

* win-builder (devel and release)
* R-hub (a Linux and a Windows target)

## R CMD check results

0 errors | 0 warnings | 1 note

The note is:

```
* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Ronald (Ryy) G Thomas <rgthomas@ucsd.edu>'
  New submission
```

This note is expected for a first-time submission.

A second note may appear on some local machines, 'checking HTML version of
manual ... NOTE: tidy doesn't look like recent enough HTML Tidy'. It
reflects an outdated HTML Tidy binary on the checking machine (for example
the version Apple bundles with macOS), not the package, and does not occur
on the CRAN check machines.

## Reverse dependencies

None. This is a new package with no reverse dependencies.
