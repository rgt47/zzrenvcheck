# Validation and Comparison Logic
# Port from validation.sh lines 345-563

#' Check Package Dependencies
#'
#' Validates that all R packages used in code are properly declared in
#' DESCRIPTION and locked in renv.lock for reproducibility.
#'
#' @param strict Logical. If TRUE, scans tests/ and vignettes/ directories.
#'   Default: TRUE.
#' @param auto_fix Logical. If TRUE, automatically adds missing packages.
#'   Default: FALSE.
#' @param cleanup Logical. If TRUE, syncs to code (adds missing, removes
#'   unused). Equivalent to calling sync_packages(). Default: FALSE.
#' @param verbose Logical. If TRUE, lists all issues found. Default: TRUE.
#' @param validate_sources Logical. If TRUE, checks if packages are installable
#'   from CRAN/Bioconductor/GitHub before adding. Default: TRUE when auto_fix.
#' @param path Character. Path to project root. Default: current directory.
#'
#' @return Invisibly returns a list with validation results
#'
#' @examples
#' \dontrun{
#' # Basic validation
#' check_packages()
#'
#' # Auto-fix missing packages
#' check_packages(auto_fix = TRUE)
#'
#' # Cleanup mode: sync to code (remove unused, add missing)
#' check_packages(cleanup = TRUE)
#'
#' # Non-strict mode (skip tests and vignettes)
#' check_packages(strict = FALSE)
#' }
#'
#' @export
check_packages <- function(strict = TRUE,
                           auto_fix = FALSE,
                           cleanup = FALSE,
                           verbose = TRUE,
                           validate_sources = auto_fix,
                           path = ".") {

  if (cleanup) {
    return(sync_packages(strict = strict, path = path, verbose = verbose))
  }

  cli::cli_h1("Package Dependency Validation")

  path <- normalizePath(path, mustWork = FALSE)

  if (!has_description(path)) {
    cli::cli_alert_danger("DESCRIPTION file not found at {.path {path}}")
    return(invisible(NULL))
  }

  dirs <- if (strict) STRICT_DIRS else STANDARD_DIRS

  if (strict) {
    cli::cli_alert_info(
      "Running in {.strong strict mode} (scanning all directories)"
    )
  }

  cli::cli_alert_info(
    "Scanning directories: {.path {paste(dirs, collapse = ', ')}}"
  )

  raw_packages <- extract_code_packages(dirs = dirs, path = path)
  code_packages <- clean_package_names(raw_packages)

  desc_packages <- parse_description_imports(path = path)

  renv_packages <- if (has_renv_lock(path)) {
    parse_renv_lock(path = path)
  } else {
    character(0)
  }

  cli::cli_alert_success(
    "Found {.strong {length(code_packages)}} package{?s} in code"
  )
 cli::cli_alert_success(
    "Found {.strong {length(desc_packages)}} package{?s} in DESCRIPTION Imports"
  )

  if (has_renv_lock(path)) {
    cli::cli_alert_success(
      "Found {.strong {length(renv_packages)}} package{?s} in renv.lock"
    )
  }

  missing_in_desc <- setdiff(code_packages, desc_packages)

  missing_in_lock <- if (has_renv_lock(path)) {
    setdiff(desc_packages, c(renv_packages, BASE_PACKAGES))
  } else {
    character(0)
  }

  unused_in_desc <- setdiff(desc_packages, code_packages)
  unused_in_desc <- setdiff(unused_in_desc, "renv")

  result <- list(
    code_packages = code_packages,
    description_packages = desc_packages,
    renv_packages = renv_packages,
    missing_in_description = missing_in_desc,
    missing_in_lock = missing_in_lock,
    unused_in_description = unused_in_desc,
    installable = character(0),
    non_installable = character(0),
    status = "unknown"
  )

  if (length(missing_in_desc) > 0) {
    cli::cli_h2("Issues Found")
    cli::cli_alert_danger(
      paste0(
        "Found {.strong {length(missing_in_desc)}} package{?s} used in code ",
        "but not in DESCRIPTION Imports"
      )
    )

    if (verbose || auto_fix) {
      cli::cli_ul(missing_in_desc)
    }

    if (auto_fix) {
      handle_auto_fix_description(missing_in_desc, path)
    } else {
      show_manual_fix_instructions(missing_in_desc)
    }

    result$status <- "fail"
  }

  if (has_renv_lock(path) && length(missing_in_lock) > 0) {
    cli::cli_h2("Reproducibility Warning")
    cli::cli_alert_danger(
      paste0(
        "Found {.strong {length(missing_in_lock)}} package{?s} in DESCRIPTION ",
        "but not in renv.lock"
      )
    )

    if (validate_sources && auto_fix) {
      validation_result <- handle_auto_fix_lock_with_validation(
        missing_in_lock, path, verbose
      )
      result$installable <- validation_result$installable
      result$non_installable <- validation_result$non_installable
    } else if (auto_fix) {
      handle_auto_fix_lock(missing_in_lock, path)
    } else {
      if (verbose) {
        cli::cli_ul(missing_in_lock)
      }
      cli::cli_alert_warning(
        "This breaks reproducibility! Collaborators cannot restore your environment."
      )
      show_manual_fix_lock_instructions(missing_in_lock)
    }

    result$status <- "fail"
  }

  if (length(unused_in_desc) > 0 && verbose) {
    cli::cli_h2("Unused Packages")
    cli::cli_alert_info(
      paste0(
        "Found {.strong {length(unused_in_desc)}} package{?s} in DESCRIPTION ",
        "but not used in code"
      )
    )
    cli::cli_ul(unused_in_desc)
    cli::cli_alert_info(
      "Run {.code check_packages(cleanup = TRUE)} to remove unused packages"
    )
  }

  if (result$status == "unknown") {
    result$status <- "pass"
    cli::cli_h2("Validation Passed")
    cli::cli_alert_success("All packages properly declared in DESCRIPTION")
    if (has_renv_lock(path)) {
      cli::cli_alert_success("All DESCRIPTION imports are locked in renv.lock")
    }
  }

  invisible(result)
}

#' Handle Auto-Fix for renv.lock with Source Validation
#'
#' Validates packages against CRAN/Bioconductor/GitHub before adding.
#' Separates installable from non-installable packages.
#'
#' @param packages Character vector of package names.
#' @param path Character. Path to project root.
#' @param verbose Logical. Show detailed output.
#'
#' @return List with installable and non_installable character vectors
#'
#' @keywords internal
handle_auto_fix_lock_with_validation <- function(packages, path, verbose) {

  cli::cli_h3("Validating Package Sources")
  cli::cli_alert_info("Checking {length(packages)} package{?s}...")

  validation <- check_installable(packages, progress = TRUE)

  installable <- validation$package[validation$installable]
  non_installable <- validation$package[!validation$installable]

  if (length(installable) > 0) {
    cli::cli_alert_success(
      "Found {length(installable)} installable package{?s}"
    )
    if (verbose) {
      for (i in which(validation$installable)) {
        cli::cli_alert_info(
          "  {validation$package[i]} ({validation$source[i]})"
        )
      }
    }

    cli::cli_h3("Auto-Fixing renv.lock")
    failed <- character(0)

    for (pkg in installable) {
      success <- add_to_renv_lock(pkg, path = path)
      if (!success) {
        failed <- c(failed, pkg)
      }
    }

    if (length(failed) == 0) {
      cli::cli_alert_success("All installable packages added to renv.lock")
    } else {
      cli::cli_alert_danger("Failed to add: {.pkg {failed}}")
    }
  }

  if (length(non_installable) > 0) {
    cli::cli_h3("Non-Installable Packages")
    cli::cli_alert_warning(
      "Found {length(non_installable)} package{?s} not on CRAN/Bioconductor/GitHub"
    )
    cli::cli_ul(non_installable)
    cli::cli_text("")
    cli::cli_alert_info("These packages require manual installation:")
    cli::cli_bullets(c(
      "GitHub: {.code remotes::install_github('owner/repo')}",
      "Bioconductor: {.code BiocManager::install('pkg')}",
      "Then: {.code renv::snapshot()}"
    ))
  }

  list(
    installable = installable,
    non_installable = non_installable
  )
}

#' Show Manual Fix Instructions
#'
#' @param packages Character vector of missing packages.
#' @keywords internal
show_manual_fix_instructions <- function(packages) {
  cli::cli_h3("How to Fix")
  cli::cli_text("Option 1: Auto-fix")
  cli::cli_code("zzrenvcheck::check_packages(auto_fix = TRUE)")
  cli::cli_text("")
  cli::cli_text("Option 2: Manual installation in container")
  cli::cli_code("make r")
  pkg_vector <- format_r_vector(packages)
  cli::cli_code(paste0("install.packages(", pkg_vector, ")"))
  cli::cli_code("q()")
}

#' Show Manual Fix Lock Instructions
#'
#' @param packages Character vector of missing packages.
#' @keywords internal
show_manual_fix_lock_instructions <- function(packages) {
  cli::cli_h3("How to Fix")
  cli::cli_text("Option 1: Auto-fix")
  cli::cli_code("zzrenvcheck::check_packages(auto_fix = TRUE)")
  cli::cli_text("")
  cli::cli_text("Option 2: Manual installation")
  cli::cli_code("make r")
  pkg_vector <- format_r_vector(packages)
  cli::cli_code(paste0("install.packages(", pkg_vector, ")"))
  cli::cli_code("q()  # Auto-snapshot on exit")
}

#' Format R Vector
#'
#' Formats package names as R vector string.
#'
#' @param packages Character vector.
#' @return Character string like 'c("pkg1", "pkg2")'
#' @keywords internal
format_r_vector <- function(packages) {
  if (length(packages) == 0) {
    return("c()")
  }

  quoted <- paste0('"', packages, '"')
  paste0("c(", paste(quoted, collapse = ", "), ")")
}
