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

  versions <- parse_renv_lock_versions(path = path)
  sort(unique(versions$package))
}

#' Parse renv.lock Package Versions
#'
#' Extracts package names and their locked exact versions from an
#' renv.lock file. Unlike \code{parse_renv_lock()}, which returns names
#' only, this retains the \code{Version} recorded for each package so
#' that cross-document version synchronisation can be validated.
#'
#' @param path Character. Path to project root containing renv.lock.
#'   Default: current directory.
#'
#' @return Data frame with columns \code{package} and \code{version}
#'   (character). Packages without a recorded version yield
#'   \code{NA_character_}. Returns a zero-row data frame when renv.lock
#'   is absent or empty.
#'
#' @keywords internal
parse_renv_lock_versions <- function(path = ".") {

  empty <- data.frame(
    package = character(0),
    version = character(0),
    stringsAsFactors = FALSE
  )

  lock_file <- file.path(path, "renv.lock")

  if (!file.exists(lock_file)) {
    cli::cli_alert_warning("renv.lock file not found at {.path {lock_file}}")
    return(empty)
  }

  tryCatch({
    lock_data <- jsonlite::fromJSON(lock_file, simplifyVector = FALSE)

    if (is.null(lock_data$Packages) || length(lock_data$Packages) == 0) {
      cli::cli_alert_info("No packages found in renv.lock")
      return(empty)
    }

    packages <- names(lock_data$Packages)

    versions <- vapply(
      lock_data$Packages,
      function(entry) {
        v <- entry$Version
        if (is.null(v) || length(v) == 0) NA_character_ else as.character(v)
      },
      character(1)
    )

    data.frame(
      package = packages,
      version = unname(versions),
      stringsAsFactors = FALSE
    )

  }, error = function(e) {
    cli::cli_alert_danger("Error parsing renv.lock: {e$message}")
    empty
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

#' Parse DESCRIPTION Imports and Suggests
#'
#' Extracts package names from both Imports and Suggests fields,
#' returning the union. This matches the validation.sh behavior
#' which treats both fields as "declared" packages.
#'
#' @param path Character. Path to project root.
#'
#' @return Character vector of package names (sorted, deduplicated)
#'
#' @keywords internal
parse_description_declared <- function(path = ".") {

  desc_file <- file.path(path, "DESCRIPTION")

  if (!file.exists(desc_file)) {
    return(character(0))
  }

  tryCatch({
    d <- desc::desc(desc_file)
    deps <- d$get_deps()
    declared <- deps[deps$type %in% c("Imports", "Suggests"), "package"]
    sort(unique(declared))
  }, error = function(e) {
    character(0)
  })
}

#' Parse Structural DESCRIPTION Dependencies
#'
#' Returns packages declared in \code{LinkingTo} or \code{Depends}. These are
#' used structurally, via compiled linkage (\code{LinkingTo}, e.g. \pkg{Rcpp})
#' or attachment (\code{Depends}), rather than through \code{library()} or
#' \code{::} in R source, so the code scanner never sees them. They must not be
#' reported as unused or removed during sync/auto-fix. The base pseudo-package
#' \code{R} (from a \code{Depends: R (>= x)} constraint) is excluded.
#'
#' @param path Character. Path to project root.
#' @return Character vector of package names (sorted, deduplicated).
#' @keywords internal
parse_description_structural <- function(path = ".") {
  deps <- parse_description_all_deps(
    path = path,
    types = c("LinkingTo", "Depends")
  )
  if (nrow(deps) == 0) {
    return(character(0))
  }
  sort(unique(setdiff(deps$package, "R")))
}

#' Parse Version-Pinned DESCRIPTION Remotes
#'
#' Extracts package version pins from the \code{Remotes:} field of a
#' DESCRIPTION file. A remote reference is a git ref, so only
#' version-like refs are returned: a leading \code{v} is stripped and the
#' remainder must begin with a digit (e.g. \code{owner/repo@@v1.1.0} or
#' \code{owner/repo@@1.1.0}). Branch names, tags such as \code{devel}, and
#' commit SHAs are not comparable to an \code{renv.lock} version and are
#' skipped. Type prefixes (\code{github::}, \code{gitlab::}, ...) are
#' removed; the package name is taken from the final path segment of the
#' repository.
#'
#' @param path Character. Path to project root.
#'
#' @return Data frame with columns \code{package} and \code{version}
#'   (character); zero rows when no version-like remotes are declared.
#'
#' @keywords internal
parse_description_remotes <- function(path = ".") {

  empty <- data.frame(
    package = character(0),
    version = character(0),
    stringsAsFactors = FALSE
  )

  desc_file <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_file)) {
    return(empty)
  }

  remotes <- tryCatch({
    d <- desc::desc(desc_file)
    r <- d$get_remotes()
    if (is.null(r)) character(0) else r
  }, error = function(e) character(0))

  if (length(remotes) == 0) {
    return(empty)
  }

  pkgs <- character(0)
  vers <- character(0)

  for (rem in remotes) {
    rem <- sub("^[a-zA-Z]+::", "", trimws(rem))
    if (!grepl("@", rem, fixed = TRUE)) {
      next
    }
    spec <- strsplit(rem, "@", fixed = TRUE)[[1]]
    pkg <- sub(".*/", "", spec[1])
    ver <- sub("^[vV]", "", spec[2])
    if (!grepl("^[0-9]", ver)) {
      next
    }
    pkgs <- c(pkgs, pkg)
    vers <- c(vers, ver)
  }

  if (length(pkgs) == 0) {
    return(empty)
  }

  res <- data.frame(package = pkgs, version = vers, stringsAsFactors = FALSE)
  valid <- clean_package_names(res$package)
  res <- res[res$package %in% valid, , drop = FALSE]
  unique(res)
}

#' Parse the Project's Own Package Name
#'
#' Reads the \code{Package:} field from DESCRIPTION. Analysis reports
#' often call \code{library(<own_pkg>)} to load the workspace package
#' itself; that self-reference must never be treated as a missing
#' dependency, as a package cannot import itself.
#'
#' @param path Character. Path to project root.
#'
#' @return Character scalar package name, or \code{character(0)} if the
#'   field is absent or unreadable.
#'
#' @keywords internal
parse_description_package_name <- function(path = ".") {

  desc_file <- file.path(path, "DESCRIPTION")

  if (!file.exists(desc_file)) {
    return(character(0))
  }

  tryCatch({
    d <- desc::desc(desc_file)
    name <- d$get_field("Package", default = NA_character_)
    if (is.na(name) || !nzchar(name)) character(0) else name
  }, error = function(e) {
    character(0)
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
