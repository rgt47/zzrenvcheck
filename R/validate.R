# Package Source Validation Functions

#' Fetch URL as Text
#'
#' Downloads a URL and returns the body as a character string.
#' Returns NULL on any error or non-zero HTTP status.
#'
#' @param url Character. URL to fetch.
#' @param timeout Integer. Seconds before timeout. Default: 10.
#' @param headers Named character vector. Extra HTTP headers. Default: NULL.
#'
#' @return Character string of response body, or NULL on failure.
#'
#' @keywords internal
http_get_text <- function(url, timeout = 10, headers = NULL) {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  old <- options(timeout = timeout)
  on.exit(options(old), add = TRUE)
  status <- tryCatch(
    download.file(url, tmp, quiet = TRUE, headers = headers,
                  method = "libcurl"),
    error = function(e) 1L
  )
  if (!identical(status, 0L)) return(NULL)
  paste(readLines(tmp, warn = FALSE), collapse = "\n")
}

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
    content <- http_get_text(url, timeout = 10)
    if (is.null(content)) return(NULL)
    jsonlite::fromJSON(content)
  }, error = function(e) NULL)
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
#' @param version Character. Bioconductor version. Default: "3.21".
#'
#' @return List with package information, or NULL if not found
#'
#' @keywords internal
fetch_bioc_info <- function(package, version = "3.21") {
  url <- paste0(
    "https://bioconductor.org/packages/json/", version, "/bioc/packages.json"
  )
  tryCatch({
    content <- http_get_text(url, timeout = 15)
    if (is.null(content)) return(NULL)
    all_packages <- jsonlite::fromJSON(content)
    if (package %in% names(all_packages)) return(all_packages[[package]])
    NULL
  }, error = function(e) NULL)
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
  if (!grepl("/", package)) return(FALSE)
  url <- paste0("https://api.github.com/repos/", package)
  !is.null(
    http_get_text(url, timeout = 10,
                  headers = c("User-Agent" = "zzrenvcheck"))
  )
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

 # Capture the bar id and pass it explicitly. cli scopes a progress bar to
 # the frame that created it; cli_progress_update() called from the lapply()
 # closure runs in a different environment and cannot find the bar by default
 # ("Cannot find current progress bar"). The id makes the reference explicit.
 pb <- if (progress) {
   cli::cli_progress_bar(
     "Validating packages",
     total = length(packages),
     clear = FALSE
   )
 } else {
   NULL
 }

 results <- lapply(packages, function(pkg) {
   result <- is_installable(
     pkg,
     check_cran = check_cran,
     check_bioc = check_bioc,
     check_github = check_github
   )

   if (progress) {
     cli::cli_progress_update(id = pb)
   }

   result
 })

 if (progress) {
   cli::cli_progress_done(id = pb)
 }

 data.frame(
   package = vapply(results, `[[`, character(1), "package"),
   installable = vapply(results, `[[`, logical(1), "installable"),
   source = vapply(results, `[[`, character(1), "source"),
   stringsAsFactors = FALSE
 )
}
