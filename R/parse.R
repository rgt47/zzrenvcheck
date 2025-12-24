# DESCRIPTION and renv.lock Parsing Functions
# Port from validation.sh lines 561-816

#' Parse DESCRIPTION Imports
#'
#' Extracts package names from the Imports field of a DESCRIPTION file.
#' Handles multi-line continuation and removes version constraints.
#'
#' @param path Character. Path to project root containing DESCRIPTION.
#'   Default: current directory.
#'
#' @return Character vector of package names (sorted, deduplicated)
#'
#' @examples
#' \dontrun{
#' imports <- parse_description_imports()
#' }
#'
#' @export
parse_description_imports <- function(path = ".") {

  desc_file <- file.path(path, "DESCRIPTION")

  if (!file.exists(desc_file)) {
    cli::cli_alert_warning("DESCRIPTION file not found at {.path {desc_file}}")
    return(character(0))
  }

  tryCatch({
    # Use desc package for robust DESCRIPTION parsing
    d <- desc::desc(desc_file)

    # Get all dependencies
    deps <- d$get_deps()

    # Filter for Imports only
    imports <- deps[deps$type == "Imports", "package"]

    sort(unique(imports))

  }, error = function(e) {
    cli::cli_alert_danger("Error parsing DESCRIPTION: {e$message}")
    character(0)
  })
}

#' Parse renv.lock Packages
#'
#' Extracts package names from an renv.lock file.
#'
#' @param path Character. Path to project root containing renv.lock.
#'   Default: current directory.
#'
#' @return Character vector of package names (sorted, deduplicated)
#'
#' @examples
#' \dontrun{
#' locked_packages <- parse_renv_lock()
#' }
#'
#' @export
parse_renv_lock <- function(path = ".") {

  lock_file <- file.path(path, "renv.lock")

  if (!file.exists(lock_file)) {
    cli::cli_alert_warning("renv.lock file not found at {.path {lock_file}}")
    return(character(0))
  }

  tryCatch({
    # Parse JSON with jsonlite
    lock_data <- jsonlite::fromJSON(lock_file, simplifyVector = FALSE)

    # Extract package names from Packages section
    if (is.null(lock_data$Packages)) {
      cli::cli_alert_info("No packages found in renv.lock")
      return(character(0))
    }

    packages <- names(lock_data$Packages)

    sort(unique(packages))

  }, error = function(e) {
    cli::cli_alert_danger("Error parsing renv.lock: {e$message}")
    character(0)
  })
}

#' Parse DESCRIPTION All Dependencies
#'
#' Extracts all package dependencies (Imports, Suggests, Depends) from DESCRIPTION.
#'
#' @param path Character. Path to project root.
#' @param types Character vector. Dependency types to include.
#'   Default: c("Imports", "Suggests", "Depends").
#'
#' @return Data frame with columns: package, type, version
#'
#' @examples
#' \dontrun{
#' all_deps <- parse_description_all_deps()
#' }
#'
#' @export
parse_description_all_deps <- function(path = ".",
                                        types = c("Imports", "Suggests", "Depends")) {

  desc_file <- file.path(path, "DESCRIPTION")

  if (!file.exists(desc_file)) {
    return(data.frame(
      package = character(0),
      type = character(0),
      version = character(0),
      stringsAsFactors = FALSE
    ))
  }

  tryCatch({
    d <- desc::desc(desc_file)
    deps <- d$get_deps()

    # Filter for requested types
    deps <- deps[deps$type %in% types, ]

    deps

  }, error = function(e) {
    cli::cli_alert_danger("Error parsing DESCRIPTION: {e$message}")
    data.frame(
      package = character(0),
      type = character(0),
      version = character(0),
      stringsAsFactors = FALSE
    )
  })
}

#' Check if DESCRIPTION Exists
#'
#' @param path Character. Path to project root.
#' @return Logical.
#' @keywords internal
has_description <- function(path = ".") {
  file.exists(file.path(path, "DESCRIPTION"))
}

#' Check if renv.lock Exists
#'
#' @param path Character. Path to project root.
#' @return Logical.
#' @keywords internal
has_renv_lock <- function(path = ".") {
  file.exists(file.path(path, "renv.lock"))
}
