# zzrenvcheck v0.7.0

* Auto-fix now places packages by role. A package used by the compendium's own
  code in `R/` is added to `Imports`; one used only by `analysis/`, `scripts/`,
  `tests/`, or `vignettes/` is added to `Suggests`. Previously every added
  package went to `Imports`.

* Structural dependencies are honoured. Packages declared in `LinkingTo` or
  `Depends` (for example `Rcpp` for compiled code) are used via linkage or
  attachment, not `library()`/`::`, so the code scanner never sees them. They
  are no longer reported as unused, and `sync`/`fresh` no longer removes them
  from `DESCRIPTION` or `renv.lock`.

# zzrenvcheck v0.6.0

* Code scanning is now chunk-aware for R Markdown and Quarto. Only fenced
  `` ```{r} `` code chunks and inline `` `r ...` `` spans are scanned for
  package references; markdown and LaTeX prose is ignored. Previously a
  `pkg::fn` written in prose (for example `\texttt{Exact::exact.test}` in a
  methods description, or `remotes::install_github(...)` in install
  instructions) was miscounted as a code dependency. Real usage in code chunks
  and inline code is still detected.

* `extract_code_packages()` (and therefore `check_packages()`) now honours
  `.renvignore`. Files excluded from renv's dependency scan (for example a
  host-rendered submission manuscript with its own toolchain) are excluded
  here too, so the two scanners agree. A gitignore-lite subset is supported
  (bare filenames, exact relative paths, globs, directory substrings); renv
  itself continues to apply full gitignore semantics.

# zzrenvcheck v0.5.0

* `check_packages()` gains a `fresh` argument. When `TRUE` it rebuilds
  `renv.lock` from a clean code scan: every package used by the code, and
  its transitive dependencies, is re-resolved to the current repository
  version and overwritten in the lockfile, and packages no longer used by
  code are pruned. This is a deliberate version refresh (it can pull
  breaking updates), distinct from ordinary `auto_fix`, which reconciles
  presence but preserves existing pins. It is intended for use after a base
  image or repository-snapshot change; run it in the container so versions
  resolve against the pinned snapshot. `fresh` routes through
  `sync_packages()`, which also syncs DESCRIPTION. Default: `FALSE`.

# zzrenvcheck v0.4.0

* `check_packages()` now validates **version consistency** across
  DESCRIPTION constraints, `renv.lock`, and version-pinned installs in
  code. Reproducibility requires that a package resolve to compatible
  versions everywhere; a mismatch (for example DESCRIPTION requires
  `>= 2.0.0` while `renv.lock` records `1.1.0`) is reported under a new
  'Version Conflicts' section. Comparison is constraint-aware: an exact
  version must satisfy a DESCRIPTION constraint, and two exact pins must
  agree. The check is report-only and is controlled by the new
  `versions` argument (default `TRUE`). Results are returned in the
  `version_conflicts` element.
* Added `extract_code_package_versions()`, which extracts version-pinned
  installs from code. Recognised forms are pak and renv `@`-syntax
  (`pak::pak('dplyr@1.1.0')`, including vectorised and multi-argument
  calls) and the `remotes`/`devtools` `install_version()` function
  (named, positional, or `package =`/`version =` argument shapes). In
  addition to the usual scanned directories, reproducibility files
  (`Dockerfile`, `install.sh`, `Makefile`, `.Rprofile`) are scanned for
  pins, since these commonly drift from `renv.lock`.
* Version-like pins in the DESCRIPTION `Remotes:` field (for example
  `owner/repo@v1.1.0`) are parsed and reconciled against `renv.lock`.
* Added the `error_on_fail` argument to `check_packages()`. When `TRUE`,
  a failing validation raises a `zzrenvcheck_validation_failure`
  condition so that a non-interactive `Rscript` run exits non-zero,
  matching the shell script's behaviour. Default `FALSE` preserves the
  returned-result behaviour.
* The shell validator (`modules/validation.sh`) mirrors all of the above
  through `check_version_conflicts()` and exits non-zero on any
  conflict.
* Corrected an over-broad path filter: files were skipped when any
  ancestor directory name merely contained a skip token (for example
  `renv`); the filter now matches a path segment.

## Known limitations

* pak requirement and keyword refs (`pkg@>=1.6.0`, `pkg@last`,
  `pkg@current`) are not exact pins and are not compared; only exact
  `pkg@version` pins are checked.
* Scanning is line-based, so a version pin split across multiple lines
  (for example a `pak::pak(c(...))` call with one package per line) is
  not detected.

# zzrenvcheck v0.3.2

* Added a vignette, 'renv vs zzrenvcheck', explaining how the two tools
  differ and complement each other (`renv` manages the environment;
  zzrenvcheck audits the code/DESCRIPTION/renv.lock declarations). `renv`
  is now listed under Suggests for the vignette.

* Fixed `check_packages()` and `sync_packages()` adding the workspace's
  own package to its DESCRIPTION Imports when a report calls
  `library(<own_pkg>)`. A package can no longer be made to depend on
  itself (a self-cycle that `R CMD check` rejects).
* Fixed a crash in `check_installable()` when reporting progress
  ('Cannot find current progress bar'); the progress-bar id is now passed
  explicitly.
* Network-dependent tests now also require a configured CRAN mirror, so
  `R CMD check` no longer errors when run without one.
* Documented the `transitive` argument and added the missing `utils` and
  `stats` imports. `R CMD check` passes with no errors, warnings, or
  notes.

# zzrenvcheck v0.3.0

* Initial public release.
