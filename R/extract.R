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

  # Honour .renvignore so files excluded from renv's dependency scan (for
  # example host-rendered manuscripts with their own toolchain) are excluded
  # here too, keeping the two scanners in agreement.
  filter_renvignore(unique(files), path)
}

#' Read .renvignore Patterns
#'
#' Reads the project's \code{.renvignore}, returning its non-empty,
#' non-comment lines as patterns. Shared with renv so a single file governs
#' which sources are excluded from dependency scanning.
#'
#' @param path Character. Project root.
#' @return Character vector of patterns (possibly empty).
#' @keywords internal
load_renvignore <- function(path) {
  f <- file.path(path, ".renvignore")
  if (!file.exists(f)) {
    return(character(0))
  }
  pats <- trimws(readLines(f, warn = FALSE))
  pats[nzchar(pats) & !startsWith(pats, "#")]
}

#' Filter Files Against .renvignore Patterns
#'
#' Drops files whose project-relative path matches any \code{.renvignore}
#' pattern. Supports a gitignore-lite subset: bare filenames, exact relative
#' paths, glob patterns, and directory/path substrings (enough for the common
#' exclusions; renv itself applies full gitignore semantics).
#'
#' @param files Character vector of absolute file paths.
#' @param path Character. Project root.
#' @return Filtered character vector.
#' @keywords internal
filter_renvignore <- function(files, path) {
  patterns <- load_renvignore(path)
  if (length(patterns) == 0 || length(files) == 0) {
    return(files)
  }
  root <- normalizePath(path, mustWork = FALSE)
  absf <- normalizePath(files, mustWork = FALSE)
  rel <- substring(absf, nchar(root) + 2L)
  keep <- !vapply(rel, renvignore_match, logical(1), patterns = patterns)
  files[keep]
}

#' Match a Relative Path Against .renvignore Patterns
#'
#' @param rel Character. Project-relative file path.
#' @param patterns Character vector of \code{.renvignore} patterns.
#' @return TRUE if any pattern matches.
#' @keywords internal
renvignore_match <- function(rel, patterns) {
  base <- basename(rel)
  for (p in patterns) {
    q <- sub("/$", "", sub("^/", "", p))
    if (!nzchar(q)) {
      next
    }
    if (identical(base, q) || identical(rel, q)) {
      return(TRUE)
    }
    rx <- utils::glob2rx(q)
    if (grepl(rx, base) || grepl(rx, rel)) {
      return(TRUE)
    }
    if (grepl(q, rel, fixed = TRUE)) {
      return(TRUE)
    }
  }
  FALSE
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

  # In R Markdown / Quarto, only fenced ```{r} chunks and inline `r ...` are
  # executable code; package references in the surrounding markdown/LaTeX prose
  # (for example \texttt{pkg::fn} or install instructions) are documentation,
  # not dependencies. Blank every non-code line so the extractors see code only.
  lines <- mask_non_code_chunks(lines, file)

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

#' Mask Non-Code Lines in R Markdown / Quarto
#'
#' For \code{.Rmd}/\code{.qmd}/\code{.Rmarkdown} files, blanks every line that
#' is not inside a fenced R code chunk, keeping inline R code spans in prose
#' lines. Non-Rmd files pass through unchanged. This prevents package references
#' in markdown or LaTeX prose (for example a namespaced call written inside
#' \\texttt in a methods description, or install instructions) from being
#' counted as code dependencies.
#'
#' @param lines Character vector of file lines.
#' @param file Character. File path (used only for its extension).
#' @return Character vector the same length as \code{lines}; non-code lines are
#'   empty strings.
#' @keywords internal
mask_non_code_chunks <- function(lines, file) {

  ext <- tolower(tools::file_ext(file))
  if (!ext %in% c("rmd", "qmd", "rmarkdown")) {
    return(lines)
  }

  # A chunk opens with a fence followed by '{r' (or '{R'), e.g. ```{r label}.
  open <- grepl("^\\s*`{3,}\\s*\\{[rR][ ,}]", lines, perl = TRUE)
  # A chunk closes with a bare fence line.
  close <- grepl("^\\s*`{3,}\\s*$", lines, perl = TRUE)

  out <- character(length(lines))
  in_chunk <- FALSE
  for (i in seq_along(lines)) {
    if (!in_chunk && open[i]) {
      in_chunk <- TRUE
      next
    }
    if (in_chunk && close[i]) {
      in_chunk <- FALSE
      next
    }
    if (in_chunk) {
      out[i] <- lines[i]
    } else {
      # Prose line: keep only inline `r ...` code spans, drop the rest.
      inline <- regmatches(
        lines[i],
        gregexpr("`r +[^`]+`", lines[i], perl = TRUE)
      )[[1]]
      if (length(inline) > 0) {
        out[i] <- paste(inline, collapse = " ")
      }
    }
  }

  out
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
