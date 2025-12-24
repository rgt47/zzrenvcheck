# Utility Functions

#' Report Package Status
#'
#' Reports the current status of package dependencies without making changes.
#' Provides a clear summary of packages in code, DESCRIPTION, and renv.lock.
#'
#' @inheritParams check_packages
#'
#' @return A data frame with package status
#'
#' @examples
#' \dontrun{
#' # View package status
#' status <- report_packages()
#' print(status)
#' }
#'
#' @export
report_packages <- function(strict = FALSE, path = ".") {

  # Extract packages
  dirs <- if (strict) STRICT_DIRS else STANDARD_DIRS
  raw_packages <- extract_code_packages(dirs = dirs, path = path)
  code_packages <- clean_package_names(raw_packages)

  # Parse DESCRIPTION and renv.lock
  desc_packages <- parse_description_imports(path = path)
  renv_packages <- if (has_renv_lock(path)) {
    parse_renv_lock(path = path)
  } else {
    character(0)
  }

  # Compile all unique packages
  all_packages <- unique(c(code_packages, desc_packages, renv_packages))

  # Create status data frame
  status_df <- data.frame(
    package = all_packages,
    in_code = all_packages %in% code_packages,
    in_description = all_packages %in% desc_packages,
    in_renv_lock = all_packages %in% renv_packages,
    stringsAsFactors = FALSE
  )

  # Determine status
  status_df$status <- apply(status_df, 1, function(row) {
    in_code <- as.logical(row["in_code"])
    in_desc <- as.logical(row["in_description"])
    in_lock <- as.logical(row["in_renv_lock"])

    if (in_code && in_desc && in_lock) {
      "ok"
    } else if (in_code && !in_desc) {
      "missing_description"
    } else if (in_desc && !in_lock) {
      "missing_lock"
    } else if (in_desc && !in_code) {
      "unused"
    } else {
      "unknown"
    }
  })

  # Sort by status (problems first)
  status_order <- c("missing_description", "missing_lock", "unused", "ok", "unknown")
  status_df$status <- factor(status_df$status, levels = status_order)
  status_df <- status_df[order(status_df$status, status_df$package), ]

  # Reset row names
  rownames(status_df) <- NULL

  # Print summary
  cli::cli_h2("Package Dependency Report")

  if (has_description(path)) {
    cli::cli_alert_info("DESCRIPTION: {sum(status_df$in_description)} package{?s}")
  }

  if (has_renv_lock(path)) {
    cli::cli_alert_info("renv.lock: {sum(status_df$in_renv_lock)} package{?s}")
  }

  cli::cli_alert_info("Code: {sum(status_df$in_code)} package{?s}")

  # Count issues
  n_missing_desc <- sum(status_df$status == "missing_description")
  n_missing_lock <- sum(status_df$status == "missing_lock")
  n_unused <- sum(status_df$status == "unused")

  if (n_missing_desc > 0) {
    cli::cli_alert_warning("{n_missing_desc} package{?s} missing from DESCRIPTION")
  }

  if (n_missing_lock > 0) {
    cli::cli_alert_warning("{n_missing_lock} package{?s} missing from renv.lock")
  }

  if (n_unused > 0) {
    cli::cli_alert_info("{n_unused} unused package{?s} in DESCRIPTION")
  }

  if (n_missing_desc == 0 && n_missing_lock == 0) {
    cli::cli_alert_success("All dependencies properly declared")
  }

  invisible(status_df)
}

#' Clean Unused Packages from DESCRIPTION
#'
#' Removes packages from DESCRIPTION Imports that are not used in code.
#' This helps keep DESCRIPTION aligned with actual dependencies.
#'
#' @inheritParams check_packages
#'
#' @return Invisibly returns character vector of removed packages
#'
#' @examples
#' \dontrun{
#' # Remove unused packages
#' clean_description()
#'
#' # Strict mode (check all directories)
#' clean_description(strict = TRUE)
#' }
#'
#' @export
clean_description <- function(strict = TRUE, path = ".") {

  if (!has_description(path)) {
    cli::cli_alert_danger("DESCRIPTION file not found")
    return(invisible(character(0)))
  }

  # Extract packages from code
  dirs <- if (strict) STRICT_DIRS else STANDARD_DIRS
  raw_packages <- extract_code_packages(dirs = dirs, path = path)
  code_packages <- clean_package_names(raw_packages)

  # Get packages in DESCRIPTION
  desc_packages <- parse_description_imports(path = path)

  # Find unused packages
  unused <- setdiff(desc_packages, code_packages)

  # Protect renv
  unused <- setdiff(unused, "renv")

  if (length(unused) == 0) {
    cli::cli_alert_success("No unused packages found")
    return(invisible(character(0)))
  }

  cli::cli_alert_info("Found {length(unused)} unused package{?s}")
  cli::cli_ul(unused)

  # Remove from DESCRIPTION
  desc_file <- file.path(path, "DESCRIPTION")
  d <- desc::desc(desc_file)

  for (pkg in unused) {
    d$del_dep(pkg)
    cli::cli_alert_success("Removed {.pkg {pkg}} from DESCRIPTION")
  }

  d$write()

  cli::cli_alert_info("Next: Update renv.lock with renv::snapshot()")

  invisible(unused)
}
