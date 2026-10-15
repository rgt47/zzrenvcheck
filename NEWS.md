# zzrenvcheck 0.10.0

## New feature

* **Research-compendium archetype exemption.**
  `check_packages()` gains a `compendium` parameter (`"auto"`, `TRUE`,
  `FALSE`; default `"auto"`). In compendium mode (activated automatically
  when an `analysis/` directory is present at the project root), only
  packages used in `R/` are required in DESCRIPTION; packages used only
  in `analysis/` or `scripts/` need only appear in `renv.lock`. This
  matches the archetype-conditional rule documented in the book
  *Reproducible Research for the Health Sciences* (ch. 4). The
  `renv.lock` completeness check is unchanged in both modes: every
  package used anywhere (including `analysis/`) must be locked.
  A new internal constant `PACKAGE_API_DIRS` (`c("R")`) identifies the
  directories that form the package API.

# zzrenvcheck 0.9.0

## Breaking change

* **`check_packages()` now fails by default when not interactive.**
  The default is `error_on_fail = !interactive()`. Under `Rscript`, in
  a Makefile target, or in CI, a failed check signals a
  `zzrenvcheck_validation_failure` error, so the process exits with a
  nonzero status; an interactive console session still only reports.
  Previously the default was `FALSE`, so a non-interactive gate
  printed the failure and exited 0, and any script or CI step that did
  not pass `error_on_fail = TRUE` could never fail. CI should still
  pass `error_on_fail = TRUE` explicitly. Pass `error_on_fail = FALSE`
  to restore report-only behavior in a script.

* **With `auto_fix = TRUE`, the gate decides on what remains after the
  fix.** When `error_on_fail` is TRUE, the repaired files are re-checked
  quietly and the error is raised only if issues survive (for example a
  version conflict, which auto-fix does not repair, or a package that
  could not be added). The result gains `status_after_fix`.

## Correctness fixes

* **The auto-fix records the installed version.** A package added to
  `renv.lock` (without `transitive`) now gets the version installed in
  the current library, with its `Repository` field, or its GitHub
  remote fields when it was installed from GitHub. It previously
  recorded whatever version CRAN served at that moment, which can
  differ from the version the code was run against. The current CRAN
  version is used only when the package is not installed, and a
  message says so. The shell implementation
  (`modules/validation.sh`) mirrors this when `Rscript` is available.

* **A package added to DESCRIPTION by the auto-fix is locked in the
  same run.** It was previously added to `renv.lock` only on a second
  run, because the set of packages missing from the lockfile was
  computed before DESCRIPTION was fixed.

# zzrenvcheck 0.8.0

## Correctness fixes

* **`requireNamespace()` and `loadNamespace()` are now recognised.**
  These are the standard idioms for using an optional dependency, and
  the form CRAN expects for anything in `Suggests`. Neither matched the
  `require(` pattern, because `requireNamespace` is not followed by a
  parenthesis at that point, nor the `::` pattern, which needs the
  operator. A package used only through this idiom was therefore absent
  from the extracted dependency set: the package reported nothing wrong
  while the dependency went undeclared, which is precisely the failure
  this package exists to prevent.

* **A namespaced call with space around the operator is now found.**
  R accepts `pkg :: fn()`; the pattern required `pkg::` with no space,
  so such a call was missed.

* **Package names in comments and string literals are no longer
  counted.** Comment stripping was line-based, matching only lines that
  begin with `#`, so a trailing comment such as `x <- 1  # see
  dplyr::filter` contributed `dplyr`, as did any string containing a
  namespaced call. Both produced spurious "used in code but not
  declared" findings, which `check_packages(auto_fix = TRUE)` would
  then act on by adding a dependency the project does not have. The
  `::` extractor now runs over lines whose string contents and
  end-of-line comments have been blanked by a new internal
  `mask_strings_and_comments()`. `library()` and `require()` still see
  the raw lines, since they legitimately take a quoted name.

## Tests

* New `test_extract_idioms.R` covers every idiom above in both
  directions: the three that were missed, the three that were counted
  in error, and the seven that already worked, so a future change
  cannot fix one direction by breaking the other.
* Suite grows from 150 assertions to 170.

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
  installs from code. Recognized forms are pak and renv `@`-syntax
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
  matching the shell script's behavior. Default `FALSE` preserves the
  returned-result behavior.
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
