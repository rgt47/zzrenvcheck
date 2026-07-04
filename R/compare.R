# Validation and Comparison Logic
# Port from validation.sh lines 345-563

#' Check Package Dependencies
#'
#' Validates that all R packages used in code are properly declared in
#' DESCRIPTION and locked in renv.lock for reproducibility.
#'
#' This complements, rather than replaces, \pkg{renv}. \pkg{renv} confirms the
#' lockfile matches the \emph{installed} library; \code{check_packages()}
#' confirms the code, DESCRIPTION, and lockfile all \emph{agree}. It is
#' declaration-only: it reads source files and the two manifests and never
#' inspects an installed library, so it runs without a container or an
#' installed environment (for example on the host or in CI, while the container
#' holds the real packages).
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
#' @param transitive Logical. If TRUE, also resolve and add transitive
#'   dependencies when fixing renv.lock. Default: FALSE.
#' @param versions Logical. If TRUE, check that package versions are
#'   consistent across DESCRIPTION constraints, renv.lock, and code
#'   install pins. Default: TRUE.
#' @param fresh Logical. If TRUE, rebuild renv.lock from a clean code scan,
#'   re-resolving every package and its transitive dependencies to the current
#'   repository versions instead of preserving existing pins, and pruning
#'   packages no longer used by code. A deliberate version refresh (it can pull
#'   breaking updates); ordinary \code{auto_fix} keeps pinned versions.
#'   Routes through \code{\link{sync_packages}}. Default: FALSE.
#' @param error_on_fail Logical. If TRUE, raise an error (rather than
#'   returning) when validation fails, so a non-interactive
#'   \command{Rscript} run exits with a non-zero status. The signalled
#'   condition has class \code{zzrenvcheck_validation_failure} and
#'   carries the result list in its \code{result} field. Default: FALSE.
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
                           transitive = FALSE,
                           versions = TRUE,
                           fresh = FALSE,
                           error_on_fail = FALSE,
                           path = ".") {

  if (cleanup) {
    return(sync_packages(strict = strict, path = path, verbose = verbose))
  }

  # fresh: rebuild renv.lock from a clean code scan, re-resolving every package
  # and its transitive dependencies to current repo versions instead of keeping
  # existing pins. Routes through sync_packages, which also prunes packages no
  # longer used by code and syncs DESCRIPTION. Use after changing the base image
  # or when a deliberate version bump is wanted; ordinary auto_fix preserves
  # pinned versions.
  if (fresh) {
    return(sync_packages(strict = strict, path = path, verbose = verbose,
                         transitive = TRUE, fresh = TRUE))
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

  # A package cannot depend on itself. Reports commonly call
  # library(<own_pkg>) to load the workspace package; drop that
  # self-reference so it is never proposed as a missing dependency.
  own_pkg <- parse_description_package_name(path = path)
  if (length(own_pkg) > 0) {
    code_packages <- setdiff(code_packages, own_pkg)
  }

  desc_imports <- parse_description_imports(path = path)
  desc_packages <- parse_description_declared(path = path)

  # LinkingTo/Depends packages (e.g. Rcpp) are used structurally, not via
  # library()/::, so the code scan never sees them; do not flag them as unused.
  structural_packages <- parse_description_structural(path = path)

  renv_packages <- if (has_renv_lock(path)) {
    parse_renv_lock(path = path)
  } else {
    character(0)
  }

  cli::cli_alert_success(
    "Found {.strong {length(code_packages)}} package{?s} in code"
  )
  cli::cli_alert_success(
    "Found {.strong {length(desc_packages)}} package{?s} in DESCRIPTION (Imports+Suggests)"
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
  unused_in_desc <- setdiff(unused_in_desc, c("renv", structural_packages))

  empty_versions <- data.frame(
    package = character(0),
    version = character(0),
    stringsAsFactors = FALSE
  )

  version_conflicts <- if (versions) {
    code_pins <- extract_code_package_versions(dirs = dirs, path = path)
    code_pins$source <- if (nrow(code_pins) > 0) "code" else character(0)

    remote_pins <- parse_description_remotes(path = path)
    remote_pins$source <- if (nrow(remote_pins) > 0) {
      "DESCRIPTION Remotes"
    } else {
      character(0)
    }

    detect_version_conflicts(
      desc_deps = parse_description_all_deps(path = path),
      lock_versions = if (has_renv_lock(path)) {
        parse_renv_lock_versions(path = path)
      } else {
        empty_versions
      },
      code_versions = rbind(code_pins, remote_pins)
    )
  } else {
    detect_version_conflicts(NULL, empty_versions, empty_versions)
  }

  result <- list(
    code_packages = code_packages,
    description_packages = desc_packages,
    renv_packages = renv_packages,
    missing_in_description = missing_in_desc,
    missing_in_lock = missing_in_lock,
    unused_in_description = unused_in_desc,
    version_conflicts = version_conflicts,
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
        missing_in_lock, path, verbose, transitive = transitive
      )
      result$installable <- validation_result$installable
      result$non_installable <- validation_result$non_installable
    } else if (auto_fix) {
      handle_auto_fix_lock(missing_in_lock, path, transitive = transitive)
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

  if (versions && nrow(version_conflicts) > 0) {
    cli::cli_h2("Version Conflicts")
    cli::cli_alert_danger(
      paste0(
        "Found {.strong {nrow(version_conflicts)}} package{?s} with ",
        "inconsistent versions across DESCRIPTION, renv.lock, and code"
      )
    )

    for (i in seq_len(nrow(version_conflicts))) {
      cli::cli_alert_warning(
        "{.pkg {version_conflicts$package[i]}}: {version_conflicts$issue[i]}"
      )
    }

    cli::cli_alert_info(
      "Reproducibility requires matching versions across all sources."
    )

    result$status <- "fail"
  }

  if (result$status == "unknown") {
    result$status <- "pass"
    cli::cli_h2("Validation Passed")
    cli::cli_alert_success("All packages properly declared in DESCRIPTION")
    if (has_renv_lock(path)) {
      cli::cli_alert_success("All DESCRIPTION imports are locked in renv.lock")
    }
  }

  if (error_on_fail && identical(result$status, "fail")) {
    cli::cli_alert_danger("Validation failed.")
    stop(structure(
      class = c("zzrenvcheck_validation_failure", "error", "condition"),
      list(
        message = "Package dependency validation failed.",
        call = NULL,
        result = result
      )
    ))
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
handle_auto_fix_lock_with_validation <- function(packages, path, verbose,
                                                  transitive = FALSE) {

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

    if (transitive) {
      add_with_deps_to_renv_lock(installable, path = path)
    } else {
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

#' Test Whether a Version Satisfies a Constraint
#'
#' Compares an exact version string against a DESCRIPTION-style version
#' constraint (e.g. \code{">= 1.0.0"}). An absent constraint (\code{"*"},
#' empty, or \code{NA}) is satisfied by any version. Unparseable
#' constraints are treated as satisfied so that non-standard version
#' strings never produce spurious conflicts.
#'
#' @param version Character. Exact version, e.g. \code{"1.1.0"}.
#' @param constraint Character. Constraint such as \code{">= 1.0.0"} or
#'   \code{"*"}.
#'
#' @return Logical scalar. \code{TRUE} if the constraint is satisfied.
#'
#' @keywords internal
version_satisfies <- function(version, constraint) {

  if (is.na(version) || is.na(constraint)) {
    return(TRUE)
  }

  constraint <- trimws(constraint)
  if (constraint == "" || constraint == "*") {
    return(TRUE)
  }

  parts <- regmatches(
    constraint,
    regexec("^(>=|<=|==|!=|>|<|=)?\\s*([0-9][0-9.-]*)$", constraint)
  )[[1]]

  if (length(parts) != 3) {
    return(TRUE)
  }

  op <- parts[2]
  target <- parts[3]
  if (op == "") {
    op <- ">="
  }

  cmp <- utils::compareVersion(version, target)

  switch(
    op,
    ">=" = cmp >= 0,
    ">"  = cmp > 0,
    "<=" = cmp <= 0,
    "<"  = cmp < 0,
    "==" = cmp == 0,
    "="  = cmp == 0,
    "!=" = cmp != 0,
    TRUE
  )
}

#' Detect Cross-Document Version Conflicts
#'
#' Compares the versions recorded for each package across DESCRIPTION
#' constraints, renv.lock exact versions, and exact pins drawn from code
#' and the DESCRIPTION \code{Remotes:} field, applying constraint-aware
#' rules. A package is reported when any of the following holds:
#' \enumerate{
#'   \item two pins for the package disagree (across or within sources);
#'   \item a pin differs from the renv.lock version;
#'   \item the renv.lock version violates the DESCRIPTION constraint;
#'   \item a pin violates the DESCRIPTION constraint.
#' }
#' Packages with no version data to compare, or whose only constraint is
#' \code{"*"}, never appear.
#'
#' @param desc_deps Data frame from \code{parse_description_all_deps()}
#'   with columns \code{package}, \code{type}, \code{version}.
#' @param lock_versions Data frame from \code{parse_renv_lock_versions()}
#'   with columns \code{package}, \code{version}.
#' @param code_versions Data frame of exact pins with columns
#'   \code{package}, \code{version}, and optionally \code{source} (a label
#'   such as \code{"code"} or \code{"DESCRIPTION Remotes"}). When
#'   \code{source} is absent every pin is labelled \code{"code"}.
#'
#' @return Data frame with columns \code{package}, \code{description},
#'   \code{lock}, \code{code}, and \code{issue}; zero rows when no
#'   conflicts are found.
#'
#' @keywords internal
detect_version_conflicts <- function(desc_deps, lock_versions, code_versions) {

  empty <- data.frame(
    package = character(0),
    description = character(0),
    lock = character(0),
    code = character(0),
    issue = character(0),
    stringsAsFactors = FALSE
  )

  pins <- code_versions
  if (is.null(pins) || nrow(pins) == 0) {
    pins <- data.frame(
      package = character(0),
      version = character(0),
      source = character(0),
      stringsAsFactors = FALSE
    )
  } else if (is.null(pins$source)) {
    pins$source <- "code"
  }

  pkgs <- unique(c(pins$package, lock_versions$package))
  if (length(pkgs) == 0) {
    return(empty)
  }

  rows <- list()

  for (pkg in sort(pkgs)) {

    constraint <- desc_constraint_for(desc_deps, pkg)
    lock_ver <- lock_versions$version[lock_versions$package == pkg]
    lock_ver <- if (length(lock_ver) == 0) NA_character_ else lock_ver[1]

    sub <- unique(pins[pins$package == pkg, c("version", "source"),
                       drop = FALSE])
    pin_vers <- unique(sub$version)

    issues <- character(0)

    if (length(pin_vers) > 1) {
      labelled <- paste0(sub$version, " (", sub$source, ")")
      issues <- c(issues, paste0(
        "version pins disagree: ", paste(labelled, collapse = " vs ")
      ))
    }

    if (!is.na(lock_ver) && nrow(sub) > 0) {
      for (i in seq_len(nrow(sub))) {
        if (sub$version[i] != lock_ver) {
          issues <- c(issues, paste0(
            sub$source[i], " pin ", sub$version[i],
            " != renv.lock ", lock_ver
          ))
        }
      }
    }

    has_constraint <- !is.na(constraint) &&
      !constraint %in% c("", "*")

    if (has_constraint) {
      if (!is.na(lock_ver) && !version_satisfies(lock_ver, constraint)) {
        issues <- c(issues, paste0(
          "renv.lock ", lock_ver, " violates DESCRIPTION (", constraint, ")"
        ))
      }
      for (i in seq_len(nrow(sub))) {
        if (!version_satisfies(sub$version[i], constraint)) {
          issues <- c(issues, paste0(
            sub$source[i], " pin ", sub$version[i],
            " violates DESCRIPTION (", constraint, ")"
          ))
        }
      }
    }

    if (length(issues) > 0) {
      rows[[length(rows) + 1]] <- data.frame(
        package = pkg,
        description = if (is.na(constraint)) NA_character_ else constraint,
        lock = lock_ver,
        code = if (length(pin_vers) == 0) {
          NA_character_
        } else {
          paste(pin_vers, collapse = ", ")
        },
        issue = paste(issues, collapse = "; "),
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(rows) == 0) {
    return(empty)
  }

  do.call(rbind, rows)
}

#' Pick a DESCRIPTION Version Constraint for a Package
#'
#' Returns the most informative constraint recorded for a package across
#' dependency types, preferring an explicit constraint over the wildcard
#' \code{"*"}.
#'
#' @param desc_deps Data frame with columns \code{package}, \code{version}.
#' @param pkg Character. Package name.
#'
#' @return Character scalar constraint, or \code{NA_character_} when the
#'   package is not declared.
#'
#' @keywords internal
desc_constraint_for <- function(desc_deps, pkg) {

  if (is.null(desc_deps) || nrow(desc_deps) == 0) {
    return(NA_character_)
  }

  vers <- desc_deps$version[desc_deps$package == pkg]
  if (length(vers) == 0) {
    return(NA_character_)
  }

  explicit <- vers[!is.na(vers) & !vers %in% c("", "*")]
  if (length(explicit) > 0) {
    return(explicit[1])
  }

  vers[1]
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
