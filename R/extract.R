# Package Extraction Functions
# Port from validation.sh lines 370-512

#' Extract Package References from R Code
#'
#' Scans R source files for package references including library(), require(),
#' namespace calls (pkg::function), and roxygen2 imports.
#'
#' @param dirs Character vector of directory paths to scan.
#' @param path Character. Path to project root. Default: current directory.
#' @param skip_comments Logical. Skip commented lines. Default: TRUE.
#'
#' @return Character vector of package names (may contain duplicates)
#'
#' @details
#' This function extracts packages from:
#' - library(pkg)
#' - require(pkg)
#' - pkg::function()
#' - @importFrom pkg function
#' - @import pkg
#'
#' @examples
#' \dontrun{
#' # Extract from R directory
#' packages <- extract_code_packages(dirs = "R")
#'
#' # Extract from multiple directories
#' packages <- extract_code_packages(dirs = c("R", "scripts", "tests"))
#' }
#'
#' @export
extract_code_packages <- function(dirs = c("R", "scripts", "analysis"),
                                   path = ".",
                                   skip_comments = TRUE) {

  # Normalize path
  path <- normalizePath(path, mustWork = FALSE)

  # Find all R files in specified directories
  files <- find_r_files(dirs, path)

  if (length(files) == 0) {
    cli::cli_alert_info("No R files found in: {.path {paste(dirs, collapse = ', ')}}")
    return(character(0))
  }

  cli::cli_alert_info("Scanning {length(files)} R file{?s} for package references...")

  # Extract packages from all files
  all_packages <- character(0)

  for (file in files) {
    pkgs <- extract_packages_from_file(file, skip_comments = skip_comments)
    all_packages <- c(all_packages, pkgs)
  }

  all_packages
}

#' Extract Version-Pinned Package Installs from Code
#'
#' Scans source files for package installation calls that pin an exact
#' version, recording the package name together with the pinned version.
#' Recognised forms are documented in \code{CODE_PIN_PATTERNS}: pak and
#' renv \code{@@}-syntax (\code{pak::pak('dplyr@@1.1.0')}) and the
#' \code{version=} argument of \code{remotes}/\code{devtools}
#' \code{install_version()}.
#'
#' Only explicitly pinned installs are returned; ordinary
#' \code{library()}/\code{::} references carry no version and are
#' ignored here (they are handled by \code{extract_code_packages()}).
#' Package names are filtered through \code{clean_package_names()} so the
#' same false-positive rules apply.
#'
#' @param dirs Character vector of directory paths to scan.
#' @param path Character. Path to project root. Default: current
#'   directory.
#' @param skip_comments Logical. Skip commented lines. Default: TRUE.
#'
#' @return Data frame with columns \code{package} and \code{version}
#'   (character). One row per pinned mention; the same package may appear
#'   more than once if pinned to differing versions across files.
#'
#' @examples
#' \dontrun{
#' pins <- extract_code_package_versions(dirs = c("R", "analysis"))
#' }
#'
#' @export
extract_code_package_versions <- function(dirs = c("R", "scripts", "analysis"),
                                           path = ".",
                                           skip_comments = TRUE) {

  empty <- data.frame(
    package = character(0),
    version = character(0),
    stringsAsFactors = FALSE
  )

  path <- normalizePath(path, mustWork = FALSE)
  files <- find_r_files(dirs, path)

  # Reproducibility files (Dockerfile, install.sh, ...) carry pinned
  # installs too. Scan them for versions only, never for plain names.
  repro <- file.path(path, REPRO_FILES)
  files <- unique(c(files, repro[file.exists(repro)]))

  if (length(files) == 0) {
    return(empty)
  }

  pkgs <- character(0)
  vers <- character(0)

  for (file in files) {
    lines <- tryCatch(
      readLines(file, warn = FALSE),
      error = function(e) character(0)
    )

    if (length(lines) == 0) {
      next
    }

    if (skip_comments) {
      is_roxygen <- grepl("^\\s*#'", lines)
      is_comment <- grepl("^\\s*#", lines) & !is_roxygen
      lines[is_comment] <- ""
    }

    # @-syntax: on any line that contains a pak/renv install call,
    # extract every 'pkg@version' token (handles vectors and
    # multi-argument calls, not just the first argument).
    on_call <- grepl(CODE_PIN_PATTERNS$pin_call_at, lines, perl = TRUE)
    if (any(on_call)) {
      m <- regmatches(
        lines[on_call],
        gregexec(CODE_PIN_PATTERNS$at_token, lines[on_call], perl = TRUE)
      )
      for (line_match in m) {
        if (is.matrix(line_match) && nrow(line_match) == 3) {
          pkgs <- c(pkgs, line_match[2, ])
          vers <- c(vers, line_match[3, ])
        }
      }
    }

    # version= syntax: remotes/devtools install_version() calls.
    m <- regmatches(
      lines,
      gregexec(CODE_PIN_PATTERNS$version_arg, lines, perl = TRUE)
    )
    for (line_match in m) {
      if (is.matrix(line_match) && nrow(line_match) == 3) {
        pkgs <- c(pkgs, line_match[2, ])
        vers <- c(vers, line_match[3, ])
      }
    }
  }

  if (length(pkgs) == 0) {
    return(empty)
  }

  result <- data.frame(
    package = pkgs,
    version = vers,
    stringsAsFactors = FALSE
  )

  # Apply the same false-positive filters used for plain references.
  valid <- clean_package_names(result$package)
  result <- result[result$package %in% valid, , drop = FALSE]

  unique(result)
}

#' Find R Files in Directories
#'
#' Recursively finds R source files in specified directories.
#'
#' @param dirs Character vector of directory names.
#' @param path Character. Base path.
#'
#' @return Character vector of file paths
#'
#' @keywords internal
find_r_files <- function(dirs, path = ".") {

  files <- character(0)

  for (dir in dirs) {
    dir_path <- file.path(path, dir)

    if (!dir.exists(dir_path)) {
      next
    }

    # Find all files with R extensions
    for (ext in FILE_EXTENSIONS) {
      pattern <- paste0("\\.", ext, "$")
      found <- list.files(
        dir_path,
        pattern = pattern,
        recursive = TRUE,
        full.names = TRUE
      )

      # Filter out skip files and directories
      found <- filter_skip_paths(found)

      files <- c(files, found)
    }
  }

  unique(files)
}

#' Filter Skip Paths
#'
#' Removes files matching skip patterns.
#'
#' @param files Character vector of file paths.
#'
#' @return Filtered character vector
#'
#' @keywords internal
filter_skip_paths <- function(files) {

  keep <- rep(TRUE, length(files))

  for (i in seq_along(files)) {
    file <- files[i]

    # Check if file matches skip pattern
    for (skip in SKIP_FILES) {
      if (grepl(skip, basename(file), fixed = TRUE)) {
        keep[i] <- FALSE
        break
      }
    }

    # Check if file is in skip directory. Match a path *segment*
    # (e.g. '/renv/'), not an arbitrary substring, so an unrelated
    # ancestor directory whose name merely contains a skip token
    # (e.g. a project under '.../zzrenvcheck/') is not skipped.
    sep <- .Platform$file.sep
    for (skip_dir in SKIP_DIRS) {
      needle <- paste0(sep, gsub("/", sep, skip_dir, fixed = TRUE), sep)
      if (grepl(needle, file, fixed = TRUE)) {
        keep[i] <- FALSE
        break
      }
    }
  }

  files[keep]
}

#' Extract Packages from Single File
#'
#' Extracts package references from a single R file.
#'
#' @param file Character. Path to R file.
#' @param skip_comments Logical. Skip commented lines.
#'
#' @return Character vector of package names
#'
#' @keywords internal
extract_packages_from_file <- function(file, skip_comments = TRUE) {

  # Read file
  lines <- tryCatch(
    readLines(file, warn = FALSE),
    error = function(e) character(0)
  )

  if (length(lines) == 0) {
    return(character(0))
  }

  # Remove comments if requested
  if (skip_comments) {
    # Keep roxygen comments (start with #')
    # Remove regular comments (start with #)
    is_roxygen <- grepl("^\\s*#'", lines)
    is_comment <- grepl("^\\s*#", lines) & !is_roxygen
    lines[is_comment] <- ""
  }

  packages <- character(0)

  # Extract library() calls
  lib_pkgs <- extract_library_calls(lines)
  packages <- c(packages, lib_pkgs)

  # Extract require() calls
  req_pkgs <- extract_require_calls(lines)
  packages <- c(packages, req_pkgs)

  # Extract namespace calls (pkg::function)
  ns_pkgs <- extract_namespace_calls(lines)
  packages <- c(packages, ns_pkgs)

  # Extract roxygen imports
  roxygen_pkgs <- extract_roxygen_imports(lines)
  packages <- c(packages, roxygen_pkgs)

  packages
}

#' Extract library() Calls
#'
#' @param lines Character vector of code lines.
#' @return Character vector of package names
#' @keywords internal
extract_library_calls <- function(lines) {

  # Pattern: library(pkg) or library("pkg") or library('pkg')
  pattern <- "library\\s*\\(\\s*['\"]?([a-zA-Z][a-zA-Z0-9.]*)['\"]?\\s*\\)"

  matches <- regmatches(lines, gregexpr(pattern, lines, perl = TRUE))

  # Extract package names from matches
  pkgs <- character(0)
  for (match_vec in matches) {
    if (length(match_vec) > 0 && match_vec[1] != "") {
      # Extract package name from library(pkg)
      pkg <- sub(".*library\\s*\\(\\s*['\"]?([a-zA-Z][a-zA-Z0-9.]*)['\"]?.*", "\\1", match_vec, perl = TRUE)
      pkgs <- c(pkgs, pkg)
    }
  }

  pkgs
}

#' Extract require() Calls
#'
#' @param lines Character vector of code lines.
#' @return Character vector of package names
#' @keywords internal
extract_require_calls <- function(lines) {

  # Pattern: require(pkg) or require("pkg") or require('pkg')
  pattern <- "require\\s*\\(\\s*['\"]?([a-zA-Z][a-zA-Z0-9.]*)['\"]?\\s*\\)"

  matches <- regmatches(lines, gregexpr(pattern, lines, perl = TRUE))

  # Extract package names from matches
  pkgs <- character(0)
  for (match_vec in matches) {
    if (length(match_vec) > 0 && match_vec[1] != "") {
      # Extract package name from require(pkg)
      pkg <- sub(".*require\\s*\\(\\s*['\"]?([a-zA-Z][a-zA-Z0-9.]*)['\"]?.*", "\\1", match_vec, perl = TRUE)
      pkgs <- c(pkgs, pkg)
    }
  }

  pkgs
}

#' Extract Namespace Calls
#'
#' Extracts package names from pkg::function() syntax.
#'
#' @param lines Character vector of code lines.
#' @return Character vector of package names
#' @keywords internal
extract_namespace_calls <- function(lines) {

  # Pattern: pkg:: (package name followed by ::)
  pattern <- "([a-zA-Z][a-zA-Z0-9.]*)::"

  matches <- regmatches(lines, gregexpr(pattern, lines, perl = TRUE))

  # Extract package names (remove ::)
  pkgs <- character(0)
  for (match_vec in matches) {
    if (length(match_vec) > 0 && match_vec[1] != "") {
      # Remove :: from each match
      pkg <- sub("::", "", match_vec, fixed = TRUE)
      pkgs <- c(pkgs, pkg)
    }
  }

  pkgs
}

#' Extract Roxygen Imports
#'
#' Extracts package names from roxygen2 @importFrom and @import tags.
#'
#' @param lines Character vector of code lines.
#' @return Character vector of package names
#' @keywords internal
extract_roxygen_imports <- function(lines) {

  pkgs <- character(0)

  # Pattern: @importFrom pkg
  importFrom_pattern <- "#'\\s*@importFrom\\s+([a-zA-Z][a-zA-Z0-9.]*)"
  matches <- regmatches(lines, gregexpr(importFrom_pattern, lines, perl = TRUE))

  for (match_vec in matches) {
    if (length(match_vec) > 0 && match_vec[1] != "") {
      pkg <- sub(".*@importFrom\\s+([a-zA-Z][a-zA-Z0-9.]*).*", "\\1", match_vec, perl = TRUE)
      pkgs <- c(pkgs, pkg)
    }
  }

  # Pattern: @import pkg
  import_pattern <- "#'\\s*@import\\s+([a-zA-Z][a-zA-Z0-9.]*)"
  matches <- regmatches(lines, gregexpr(import_pattern, lines, perl = TRUE))

  for (match_vec in matches) {
    if (length(match_vec) > 0 && match_vec[1] != "") {
      pkg <- sub(".*@import\\s+([a-zA-Z][a-zA-Z0-9.]*).*", "\\1", match_vec, perl = TRUE)
      pkgs <- c(pkgs, pkg)
    }
  }

  pkgs
}
