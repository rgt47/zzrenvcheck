# Configuration and Constants
# Port from validation.sh lines 24-64

#' Base R Packages
#'
#' Base R packages that don't need explicit declaration in DESCRIPTION.
#' These packages are always available in R installations.
#'
#' @keywords internal
BASE_PACKAGES <- c(
  "base", "utils", "stats", "graphics", "grDevices",
  "methods", "datasets", "tools", "grid", "parallel"
)

#' Placeholder Package Names
#'
#' Invalid or placeholder package names to exclude from validation.
#' These are commonly used in documentation examples and should not
#' be treated as real package references.
#'
#' @keywords internal
PLACEHOLDER_PACKAGES <- c(
  "package", "pkg", "mypackage", "myproject", "yourpackage",
  "project", "data", "result", "output", "input",
  "test", "example", "sample", "demo", "template",
  "local", "any", "all", "none", "NULL",
  "foo", "bar", "baz", "qux", "zzcollab"
)

#' File Extensions to Search
#'
#' R source file extensions to scan for package references.
#'
#' @keywords internal
FILE_EXTENSIONS <- c("R", "Rmd", "qmd", "Rnw")

#' Files to Skip During Scanning
#'
#' Documentation and example files that should not be scanned
#' for package dependencies (often contain example code).
#'
#' @keywords internal
SKIP_FILES <- c(
  "README.Rmd",
  "README.md",
  "CLAUDE.md"
)

#' Directories to Skip During Scanning
#'
#' Directory patterns to exclude from package scanning.
#'
#' @keywords internal
SKIP_DIRS <- c(
  "examples",
  "inst/examples",
  "man/examples",
  "renv"
)

#' Code Version-Pin Install Forms
#'
#' Patterns used by \code{extract_code_package_versions()} to recognise
#' version-pinned package installs. Two grammars are supported:
#' \itemize{
#'   \item \code{@@}-syntax: \code{pak::pak('dplyr@@1.1.0')},
#'     \code{pak('dplyr@@1.1.0')}, \code{pak::pkg_install('dplyr@@1.1.0')},
#'     \code{renv::install('dplyr@@1.1.0')}.
#'   \item \code{version=} syntax:
#'     \code{remotes::install_version('dplyr', version = '1.1.0')},
#'     \code{devtools::install_version('dplyr', version = '1.1.0')}.
#' }
#' For the \code{@@}-syntax, \code{pin_call_at} detects that a line
#' contains such an install call and \code{at_token} then extracts every
#' \code{'pkg@@version'} token on that line, so vectorised
#' (\code{pak(c('a@@1', 'b@@2'))}) and multi-argument calls are all
#' captured. The version token must begin with a digit, which excludes
#' GitHub refs (\code{owner/repo@@branch}).
#'
#' @keywords internal
CODE_PIN_PATTERNS <- list(
  pin_call_at = paste0(
    "(?:pak::pak|pak::pkg_install|pak|renv::install)\\s*\\("
  ),
  at_token = paste0(
    "['\"]([a-zA-Z][a-zA-Z0-9.]*)@([0-9][a-zA-Z0-9.-]*)['\"]"
  ),
  version_arg = paste0(
    "(?:remotes|devtools)::install_version\\s*\\(\\s*",
    "(?:package\\s*=\\s*)?",
    "['\"]([a-zA-Z][a-zA-Z0-9.]*)['\"]\\s*,\\s*",
    "(?:version\\s*=\\s*)?",
    "['\"]([0-9][a-zA-Z0-9.-]*)['\"]"
  )
)

#' Reproducibility Files Scanned for Version Pins
#'
#' Non-R project files that commonly carry version-pinned install
#' commands and can therefore drift from \code{renv.lock}. These are
#' scanned by \code{extract_code_package_versions()} only (the
#' version-synchronisation check); they are deliberately excluded from
#' the plain package-name scan, where build tooling and shell commands
#' would generate false positives.
#'
#' @keywords internal
REPRO_FILES <- c("Dockerfile", "install.sh", "Makefile", ".Rprofile")

#' Standard Directories to Scan
#'
#' Default directories scanned in standard (non-strict) mode.
#'
#' @keywords internal
STANDARD_DIRS <- c(".", "R", "scripts", "analysis")

#' Strict Mode Directories
#'
#' All directories scanned in strict mode (includes tests and vignettes).
#'
#' @keywords internal
STRICT_DIRS <- c(".", "R", "scripts", "analysis", "tests", "vignettes", "inst")
