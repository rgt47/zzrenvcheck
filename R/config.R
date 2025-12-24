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
  "foo", "bar", "baz", "qux"
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
  "man/examples"
)

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
