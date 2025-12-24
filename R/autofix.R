# Auto-Fix Functions
# Port from validation.sh lines 100-271

#' Handle Auto-Fix for DESCRIPTION
#'
#' Automatically adds missing packages to DESCRIPTION Imports.
#'
#' @param packages Character vector of package names to add.
#' @param path Character. Path to project root.
#'
#' @return Character vector of packages that failed to add
#'
#' @keywords internal
handle_auto_fix_description <- function(packages, path = ".") {

  cli::cli_h3("Auto-Fixing DESCRIPTION")
  cli::cli_alert_info("Adding {length(packages)} package{?s} to DESCRIPTION...")

  failed <- character(0)

  for (pkg in packages) {
    success <- add_to_description(pkg, path = path)
    if (!success) {
      failed <- c(failed, pkg)
    }
  }

  if (length(failed) == 0) {
    cli::cli_alert_success("All packages added to DESCRIPTION")
  } else {
    cli::cli_alert_danger("Failed to add: {.pkg {failed}}")
  }

  invisible(failed)
}

#' Handle Auto-Fix for renv.lock
#'
#' Automatically adds missing packages to renv.lock via CRAN API.
#' Does not validate package sources - use handle_auto_fix_lock_with_validation
#' for source checking.
#'
#' @param packages Character vector of package names to add.
#' @param path Character. Path to project root.
#'
#' @return Character vector of packages that failed to add
#'
#' @keywords internal
handle_auto_fix_lock <- function(packages, path = ".") {

  cli::cli_h3("Auto-Fixing renv.lock")
  cli::cli_alert_info("Adding {length(packages)} package{?s} to renv.lock...")

  failed <- character(0)

  for (pkg in packages) {
    success <- add_to_renv_lock(pkg, path = path)
    if (!success) {
      failed <- c(failed, pkg)
    }
  }

  if (length(failed) == 0) {
    cli::cli_alert_success("All packages added to renv.lock")
    cli::cli_text("")
    cli::cli_h3("Next Steps")
    cli::cli_ol(c(
      "Review changes: git diff DESCRIPTION renv.lock",
      "Commit: git add DESCRIPTION renv.lock && git commit -m 'Add packages'",
      "Rebuild Docker: make docker-build"
    ))
  } else {
    cli::cli_alert_danger("Failed to add: {.pkg {failed}}")
    cli::cli_text("These packages may not be on CRAN. Add them manually.")
  }

  invisible(failed)
}

#' Add Package to DESCRIPTION
#'
#' Adds a package to the Imports field in DESCRIPTION.
#'
#' @param package Character. Package name.
#' @param field Character. DESCRIPTION field. Default: "Imports".
#' @param path Character. Path to project root.
#'
#' @return Logical indicating success
#'
#' @keywords internal
add_to_description <- function(package, field = "Imports", path = ".") {

  desc_file <- file.path(path, "DESCRIPTION")

  if (!file.exists(desc_file)) {
    cli::cli_alert_danger("DESCRIPTION file not found")
    return(FALSE)
  }

  tryCatch({
    d <- desc::desc(desc_file)

    # Add dependency
    d$set_dep(package, type = field)

    # Write changes
    d$write()

    cli::cli_alert_success("Added {.pkg {package}} to DESCRIPTION {field}")

    TRUE

  }, error = function(e) {
    cli::cli_alert_danger("Failed to add {.pkg {package}}: {e$message}")
    FALSE
  })
}

#' Add Package to renv.lock
#'
#' Adds a package entry to renv.lock by querying CRAN API.
#'
#' @param package Character. Package name.
#' @param version Character. Package version. If NULL, fetches from CRAN.
#' @param path Character. Path to project root.
#'
#' @return Logical indicating success
#'
#' @keywords internal
add_to_renv_lock <- function(package, version = NULL, path = ".") {

  lock_file <- file.path(path, "renv.lock")

  if (!file.exists(lock_file)) {
    cli::cli_alert_danger("renv.lock file not found")
    return(FALSE)
  }

  # Fetch version from CRAN if not provided
  if (is.null(version)) {
    pkg_info <- fetch_cran_info(package)

    if (is.null(pkg_info)) {
      cli::cli_alert_danger("Package {.pkg {package}} not found on CRAN")
      return(FALSE)
    }

    version <- pkg_info$Version
  }

  tryCatch({
    # Read renv.lock
    lock_data <- jsonlite::fromJSON(lock_file, simplifyVector = FALSE)

    # Create package entry
    pkg_entry <- list(
      Package = package,
      Version = version,
      Source = "Repository",
      Repository = "CRAN"
    )

    # Add to Packages section
    if (is.null(lock_data$Packages)) {
      lock_data$Packages <- list()
    }

    lock_data$Packages[[package]] <- pkg_entry

    # Write back to file
    jsonlite::write_json(
      lock_data,
      lock_file,
      pretty = TRUE,
      auto_unbox = TRUE
    )

    cli::cli_alert_success("Added {.pkg {package}} ({version}) to renv.lock")

    TRUE

  }, error = function(e) {
    cli::cli_alert_danger("Failed to add {.pkg {package}} to renv.lock: {e$message}")
    FALSE
  })
}

#' Fix Packages (Convenience Wrapper)
#'
#' Automatically adds missing packages to DESCRIPTION and renv.lock.
#' This is a convenience wrapper around check_packages(auto_fix = TRUE).
#'
#' @inheritParams check_packages
#'
#' @return Invisibly returns a list with packages that were added
#'
#' @examples
#' \dontrun{
#' # Fix all missing packages
#' fix_packages()
#'
#' # Fix with non-strict mode
#' fix_packages(strict = FALSE)
#' }
#'
#' @export
fix_packages <- function(strict = TRUE, path = ".") {
  check_packages(strict = strict, auto_fix = TRUE, path = path)
}
