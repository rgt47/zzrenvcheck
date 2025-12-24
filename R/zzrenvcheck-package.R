#' zzrenvcheck: Validate R Package Dependencies for Reproducibility
#'
#' Validates that all R packages used in source code are properly declared
#' in DESCRIPTION and locked in renv.lock for reproducibility.
#'
#' @section Main Functions:
#' \itemize{
#'   \item \code{\link{check_packages}}: Main validation function
#'   \item \code{\link{fix_packages}}: Auto-fix missing packages
#'   \item \code{\link{report_packages}}: Generate package status report
#'   \item \code{\link{clean_description}}: Remove unused packages
#' }
#'
#' @section Package Extraction:
#' \itemize{
#'   \item \code{\link{extract_code_packages}}: Extract packages from R code
#'   \item \code{\link{clean_package_names}}: Validate and clean package names
#' }
#'
#' @section Parsing:
#' \itemize{
#'   \item \code{\link{parse_description_imports}}: Parse DESCRIPTION Imports
#'   \item \code{\link{parse_renv_lock}}: Parse renv.lock packages
#' }
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
