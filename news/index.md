# Changelog

## zzrenvcheck v0.3.2

- Added a vignette, ‘renv vs zzrenvcheck’, explaining how the two tools
  differ and complement each other (`renv` manages the environment;
  zzrenvcheck audits the code/DESCRIPTION/renv.lock declarations).
  `renv` is now listed under Suggests for the vignette.

- Fixed
  [`check_packages()`](https://rgt47.github.io/zzrenvcheck/reference/check_packages.md)
  and
  [`sync_packages()`](https://rgt47.github.io/zzrenvcheck/reference/sync_packages.md)
  adding the workspace’s own package to its DESCRIPTION Imports when a
  report calls `library(<own_pkg>)`. A package can no longer be made to
  depend on itself (a self-cycle that `R CMD check` rejects).

- Fixed a crash in
  [`check_installable()`](https://rgt47.github.io/zzrenvcheck/reference/check_installable.md)
  when reporting progress (‘Cannot find current progress bar’); the
  progress-bar id is now passed explicitly.

- Network-dependent tests now also require a configured CRAN mirror, so
  `R CMD check` no longer errors when run without one.

- Documented the `transitive` argument and added the missing `utils` and
  `stats` imports. `R CMD check` passes with no errors, warnings, or
  notes.

## zzrenvcheck v0.3.0

- Initial public release.
