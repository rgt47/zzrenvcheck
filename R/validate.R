# Package Source Validation Functions
# Port from validation.sh lines 80-106

#' Fetch CRAN Package Information
#'
#' Queries the CRAN API for package metadata.
#'
#' @param package Character. Package name.
#'
#' @return List with package information, or NULL if not found
#'
#' @keywords internal
fetch_cran_info <- function(package) {


 url <- paste0("https://crandb.r-pkg.org/", package)

 tryCatch({

   resp <- httr::GET(url, httr::timeout(10))

   if (httr::http_error(resp)) {
     return(NULL)
   }

   content <- httr::content(resp, as = "text", encoding = "UTF-8")
   pkg_info <- jsonlite::fromJSON(content)

   pkg_info

 }, error = function(e) {
   NULL
 })
}

#' Validate Package on CRAN
#'
#' Checks if a package exists on CRAN.
#'
#' @param package Character. Package name.
#'
#' @return Logical. TRUE if package exists on CRAN.
#'
#' @keywords internal
validate_cran <- function(package) {
 !is.null(fetch_cran_info(package))
}

#' Fetch Bioconductor Package Information
#'
#' Queries the Bioconductor API for package metadata.
#'
#' @param package Character. Package name.
#' @param version Character. Bioconductor version. Default: "3.19".
#'
#' @return List with package information, or NULL if not found
#'
#' @keywords internal
fetch_bioc_info <- function(package, version = "3.19") {

 url <- paste0(
   "https://bioconductor.org/packages/json/", version, "/bioc/packages.json"
 )

 tryCatch({
   resp <- httr::GET(url, httr::timeout(15))

   if (httr::http_error(resp)) {
     return(NULL)
   }

   content <- httr::content(resp, as = "text", encoding = "UTF-8")
   all_packages <- jsonlite::fromJSON(content)

   if (package %in% names(all_packages)) {
     return(all_packages[[package]])
   }

   NULL

 }, error = function(e) {
   NULL
 })
}

#' Validate Package on Bioconductor
#'
#' Checks if a package exists on Bioconductor.
#'
#' @param package Character. Package name.
#'
#' @return Logical. TRUE if package exists on Bioconductor.
#'
#' @keywords internal
validate_bioconductor <- function(package) {
 !is.null(fetch_bioc_info(package))
}

#' Validate Package on GitHub
#'
#' Checks if a package exists on GitHub. Expects format "owner/repo".
#'
#' @param package Character. Package identifier in "owner/repo" format.
#'
#' @return Logical. TRUE if repository exists on GitHub.
#'
#' @keywords internal
validate_github <- function(package) {

 if (!grepl("/", package)) {
   return(FALSE)
 }

 url <- paste0("https://api.github.com/repos/", package)

 tryCatch({
   resp <- httr::GET(
     url,
     httr::timeout(10),
     httr::add_headers("User-Agent" = "zzrenvcheck")
   )

   !httr::http_error(resp)

 }, error = function(e) {
   FALSE
 })
}

#' Check if Package is Installable
#'
#' Validates whether a package can be installed from CRAN, Bioconductor,
#' or GitHub. Returns information about the source if found.
#'
#' @param package Character. Package name or "owner/repo" for GitHub.
#' @param check_cran Logical. Check CRAN. Default: TRUE.
#' @param check_bioc Logical. Check Bioconductor. Default: TRUE.
#' @param check_github Logical. Check GitHub. Default: TRUE.
#'
#' @return A list with:
#'   - installable: Logical indicating if package can be installed
#'   - source: Character indicating source ("CRAN", "Bioconductor", "GitHub", or NA)
#'   - package: The package name
#'
#' @examples
#' \dontrun{
#' is_installable("dplyr")
#' # Returns: list(installable = TRUE, source = "CRAN", package = "dplyr")
#'
#' is_installable("NonExistentPkg123")
#' # Returns: list(installable = FALSE, source = NA, package = "NonExistentPkg123")
#' }
#'
#' @export
is_installable <- function(package,
                           check_cran = TRUE,
                           check_bioc = TRUE,
                           check_github = TRUE) {

 result <- list(
   installable = FALSE,
   source = NA_character_,
   package = package
 )

 if (check_cran && validate_cran(package)) {
   result$installable <- TRUE
   result$source <- "CRAN"
   return(result)
 }

 if (check_bioc && validate_bioconductor(package)) {
   result$installable <- TRUE
   result$source <- "Bioconductor"
   return(result)
 }

 if (check_github && validate_github(package)) {
   result$installable <- TRUE
   result$source <- "GitHub"
   return(result)
 }

 result
}

#' Check Multiple Packages for Installability
#'
#' Batch validation of package installability across CRAN, Bioconductor,
#' and GitHub.
#'
#' @param packages Character vector. Package names to check.
#' @param check_cran Logical. Check CRAN. Default: TRUE.
#' @param check_bioc Logical. Check Bioconductor. Default: TRUE.
#' @param check_github Logical. Check GitHub. Default: TRUE.
#' @param progress Logical. Show progress. Default: TRUE.
#'
#' @return A data frame with columns: package, installable, source
#'
#' @examples
#' \dontrun{
#' check_installable(c("dplyr", "ggplot2", "NonExistent"))
#' }
#'
#' @export
check_installable <- function(packages,
                              check_cran = TRUE,
                              check_bioc = TRUE,
                              check_github = TRUE,
                              progress = TRUE) {

 if (length(packages) == 0) {
   return(data.frame(
     package = character(0),
     installable = logical(0),
     source = character(0),
     stringsAsFactors = FALSE
   ))
 }

 if (progress) {
   cli::cli_progress_bar(
     "Validating packages",
     total = length(packages),
     clear = FALSE
   )
 }

 results <- lapply(packages, function(pkg) {
   result <- is_installable(
     pkg,
     check_cran = check_cran,
     check_bioc = check_bioc,
     check_github = check_github
   )

   if (progress) {
     cli::cli_progress_update()
   }

   result
 })

 if (progress) {
   cli::cli_progress_done()
 }

 data.frame(
   package = vapply(results, `[[`, character(1), "package"),
   installable = vapply(results, `[[`, logical(1), "installable"),
   source = vapply(results, `[[`, character(1), "source"),
   stringsAsFactors = FALSE
 )
}
