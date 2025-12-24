# Sync Functions
# Port from validation.sh lines 469-548

#' Sync Packages to Code
#'
#' Synchronizes DESCRIPTION and renv.lock to match packages used in code.
#' Code is treated as the source of truth. Adds missing packages and
#' removes unused packages.
#'
#' @param strict Logical. If TRUE, scans tests/ and vignettes/. Default: TRUE.
#' @param path Character. Path to project root. Default: current directory.
#' @param verbose Logical. Show detailed output. Default: FALSE.
#' @param dry_run Logical. If TRUE, only report changes without making them.
#'   Default: FALSE.
#'
#' @return Invisibly returns a list with changes made
#'
#' @details
#' This function treats code as the single source of truth:
#' - Packages used in code but not in DESCRIPTION → added to DESCRIPTION
#' - Packages in DESCRIPTION but not in code → removed from DESCRIPTION
#' - Packages used in code but not in renv.lock → added to renv.lock
#' - Packages in renv.lock but not in code → removed from renv.lock
#'
#' The "renv" package is always protected and never removed.
#'
#' @examples
#' \dontrun{
#' # Sync packages (code is source of truth)
#' sync_packages()
#'
#' # Preview changes without applying
#' sync_packages(dry_run = TRUE)
#'
#' # Sync with verbose output
#' sync_packages(verbose = TRUE)
#' }
#'
#' @export
sync_packages <- function(strict = TRUE,
                          path = ".",
                          verbose = FALSE,
                          dry_run = FALSE) {

  cli::cli_h1("Sync Packages to Code")

  if (dry_run) {
    cli::cli_alert_info("Dry run mode - no changes will be made")
  }

  path <- normalizePath(path, mustWork = FALSE)

  if (!has_description(path)) {
    cli::cli_alert_danger("DESCRIPTION file not found at {.path {path}}")
    return(invisible(NULL))
  }

  dirs <- if (strict) STRICT_DIRS else STANDARD_DIRS

  cli::cli_alert_info(
    "Syncing DESCRIPTION and renv.lock to code (code is source of truth)"
  )

  code_packages_raw <- extract_code_packages(dirs = dirs, path = path)
  code_packages <- clean_package_names(code_packages_raw)
  desc_packages <- parse_description_imports(path = path)
  renv_packages <- if (has_renv_lock(path)) {
    parse_renv_lock(path = path)
  } else {
    character(0)
  }

  cli::cli_alert_info("Found {length(code_packages)} package{?s} in code")

  if (verbose) {
    cli::cli_text("Code packages:")
    cli::cli_ul(code_packages)
  }

  to_add_desc <- setdiff(code_packages, desc_packages)
  to_remove_desc <- setdiff(desc_packages, c(code_packages, "renv"))
  to_add_lock <- setdiff(code_packages, renv_packages)
  to_remove_lock <- setdiff(renv_packages, c(code_packages, "renv"))

  changes <- list(
    added_to_description = character(0),
    removed_from_description = character(0),
    added_to_lock = character(0),
    removed_from_lock = character(0),
    failed = character(0)
  )

  if (length(to_add_desc) > 0) {
    cli::cli_h2("Adding to DESCRIPTION")
    cli::cli_alert_info("Adding {length(to_add_desc)} package{?s}")
    cli::cli_ul(to_add_desc)

    if (!dry_run) {
      for (pkg in to_add_desc) {
        success <- add_to_description(pkg, path = path)
        if (success) {
          changes$added_to_description <- c(changes$added_to_description, pkg)
        } else {
          changes$failed <- c(changes$failed, pkg)
        }
      }
    }
  }

  if (length(to_remove_desc) > 0) {
    cli::cli_h2("Removing from DESCRIPTION")
    cli::cli_alert_info("Removing {length(to_remove_desc)} unused package{?s}")
    cli::cli_ul(to_remove_desc)

    if (!dry_run) {
      removed <- remove_from_description(to_remove_desc, path = path)
      changes$removed_from_description <- removed
    }
  }

  if (has_renv_lock(path)) {
    if (length(to_add_lock) > 0) {
      cli::cli_h2("Adding to renv.lock")
      cli::cli_alert_info("Adding {length(to_add_lock)} package{?s}")

      if (!dry_run) {
        for (pkg in to_add_lock) {
          success <- add_to_renv_lock(pkg, path = path)
          if (success) {
            changes$added_to_lock <- c(changes$added_to_lock, pkg)
          } else {
            cli::cli_alert_warning(
              "Could not add {.pkg {pkg}} to renv.lock (not on CRAN?)"
            )
          }
        }
      }
    }

    if (length(to_remove_lock) > 0) {
      cli::cli_h2("Removing from renv.lock")
      cli::cli_alert_info("Removing {length(to_remove_lock)} unused package{?s}")
      cli::cli_ul(to_remove_lock)

      if (!dry_run) {
        removed <- remove_from_renv_lock(to_remove_lock, path = path)
        changes$removed_from_lock <- removed
      }
    }
  }

  cli::cli_h2("Summary")

  if (dry_run) {
    total_changes <- length(to_add_desc) + length(to_remove_desc) +
      length(to_add_lock) + length(to_remove_lock)
    if (total_changes > 0) {
      cli::cli_alert_info(
        "Would make {total_changes} change{?s} (dry run, no changes made)"
      )
    } else {
      cli::cli_alert_success("No changes needed - already in sync")
    }
  } else {
    total_changes <- length(changes$added_to_description) +
      length(changes$removed_from_description) +
      length(changes$added_to_lock) +
      length(changes$removed_from_lock)

    if (total_changes > 0) {
      cli::cli_alert_success(
        "Sync complete: DESCRIPTION and renv.lock now match code"
      )
    } else {
      cli::cli_alert_success("No changes needed - already in sync")
    }
  }

  invisible(changes)
}

#' Remove Packages from DESCRIPTION
#'
#' Removes specified packages from the Imports field in DESCRIPTION.
#'
#' @param packages Character vector. Package names to remove.
#' @param path Character. Path to project root.
#'
#' @return Character vector of successfully removed packages
#'
#' @keywords internal
remove_from_description <- function(packages, path = ".") {

  desc_file <- file.path(path, "DESCRIPTION")

  if (!file.exists(desc_file)) {
    cli::cli_alert_danger("DESCRIPTION file not found")
    return(character(0))
  }

  tryCatch({
    d <- desc::desc(desc_file)

    removed <- character(0)
    for (pkg in packages) {
      tryCatch({
        d$del_dep(pkg)
        removed <- c(removed, pkg)
        cli::cli_alert_success("Removed {.pkg {pkg}} from DESCRIPTION")
      }, error = function(e) {
        cli::cli_alert_warning("Could not remove {.pkg {pkg}}: {e$message}")
      })
    }

    d$write()
    removed

  }, error = function(e) {
    cli::cli_alert_danger("Failed to update DESCRIPTION: {e$message}")
    character(0)
  })
}

#' Remove Packages from renv.lock
#'
#' Removes specified packages from renv.lock.
#'
#' @param packages Character vector. Package names to remove.
#' @param path Character. Path to project root.
#'
#' @return Character vector of successfully removed packages
#'
#' @export
remove_from_renv_lock <- function(packages, path = ".") {

  lock_file <- file.path(path, "renv.lock")

  if (!file.exists(lock_file)) {
    cli::cli_alert_danger("renv.lock file not found")
    return(character(0))
  }

  tryCatch({
    lock_data <- jsonlite::fromJSON(lock_file, simplifyVector = FALSE)

    if (is.null(lock_data$Packages)) {
      cli::cli_alert_info("No packages in renv.lock")
      return(character(0))
    }

    removed <- character(0)
    for (pkg in packages) {
      if (pkg %in% names(lock_data$Packages)) {
        lock_data$Packages[[pkg]] <- NULL
        removed <- c(removed, pkg)
      }
    }

    if (length(removed) > 0) {
      jsonlite::write_json(
        lock_data,
        lock_file,
        pretty = TRUE,
        auto_unbox = TRUE
      )
      cli::cli_alert_success(
        "Removed {length(removed)} package{?s} from renv.lock"
      )
    }

    removed

  }, error = function(e) {
    cli::cli_alert_danger("Failed to update renv.lock: {e$message}")
    character(0)
  })
}

#' Create Empty renv.lock
#'
#' Creates a new renv.lock file with R version and repository settings.
#'
#' @param r_version Character. R version. Default: current R version.
#' @param cran_url Character. CRAN repository URL.
#'   Default: "https://cloud.r-project.org".
#' @param path Character. Path to project root. Default: current directory.
#'
#' @return Logical indicating success
#'
#' @examples
#' \dontrun{
#' # Create with current R version
#' create_renv_lock()
#'
#' # Create with specific R version
#' create_renv_lock(r_version = "4.4.0")
#' }
#'
#' @export
create_renv_lock <- function(r_version = NULL,
                             cran_url = "https://cloud.r-project.org",
                             path = ".") {

  if (is.null(r_version)) {
    r_version <- paste(R.version$major, R.version$minor, sep = ".")
  }

  lock_file <- file.path(path, "renv.lock")

  lock_data <- list(
    R = list(
      Version = r_version,
      Repositories = list(
        list(Name = "CRAN", URL = cran_url)
      )
    ),
    Packages = list()
  )

  tryCatch({
    jsonlite::write_json(
      lock_data,
      lock_file,
      pretty = TRUE,
      auto_unbox = TRUE
    )
    cli::cli_alert_success("Created renv.lock (R {r_version})")
    TRUE
  }, error = function(e) {
    cli::cli_alert_danger("Failed to create renv.lock: {e$message}")
    FALSE
  })
}
