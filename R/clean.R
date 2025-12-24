# Package Name Cleaning and Validation
# Port from validation.sh lines 452-512

#' Clean and Validate Package Names
#'
#' Applies 19 filters to remove invalid package names, base packages,
#' placeholders, and generic words that are false positives.
#'
#' @param packages Character vector of raw package names (may include duplicates).
#'
#' @return Character vector of validated package names (sorted, deduplicated)
#'
#' @details
#' Validation rules applied:
#' - Minimum 3 characters (R package requirement)
#' - Must start with a letter (a-zA-Z)
#' - Can contain letters, numbers, and dots only
#' - Cannot start or end with a dot
#' - Excludes base R packages
#' - Excludes placeholder names
#' - Excludes generic English words
#'
#' @examples
#' packages <- c("dplyr", "base", "ggplot2", "my", ".invalid", "dplyr")
#' clean_package_names(packages)
#' # Returns: c("dplyr", "ggplot2")
#'
#' @export
clean_package_names <- function(packages) {

  if (length(packages) == 0) {
    return(character(0))
  }

  cleaned <- character(0)

  for (pkg in packages) {

    # Filter 1: Skip if empty or too short (< 3 characters)
    # This removes "my", "an", "is", "or", etc.
    if (is.na(pkg) || nchar(pkg) < 3) {
      next
    }

    # Filter 2: Skip base R packages
    if (pkg %in% BASE_PACKAGES) {
      next
    }

    # Filter 3: Skip placeholder packages
    if (pkg %in% PLACEHOLDER_PACKAGES) {
      next
    }

    # Filter 4-6: Pattern-based filtering for generic words
    if (is_generic_word(pkg)) {
      next
    }

    # Filter 7-8: Validate package name format
    if (!is_valid_package_name(pkg)) {
      next
    }

    cleaned <- c(cleaned, pkg)
  }

  # Sort and deduplicate
  sort(unique(cleaned))
}

#' Check if Name is Generic Word
#'
#' Identifies generic English words commonly used in documentation
#' that should not be treated as package names.
#'
#' @param pkg Character. Package name to check.
#'
#' @return Logical. TRUE if generic word, FALSE otherwise.
#'
#' @keywords internal
is_generic_word <- function(pkg) {

  # Pronouns and articles
  pronouns <- c("my", "your", "his", "her", "our", "their", "the", "this", "that")
  if (pkg %in% pronouns) {
    return(TRUE)
  }

  # Generic nouns commonly used in examples
  nouns <- c("file", "dir", "path", "name", "value", "object",
             "function", "method", "class")
  if (pkg %in% nouns) {
    return(TRUE)
  }

  # Words ending in common suffixes (usually examples)
  # Only filter if all lowercase (real packages often use CamelCase)
  if (grepl("^[a-z]+$", pkg)) {
    suffixes <- c("analysis", "project", "study", "trial")
    for (suffix in suffixes) {
      if (grepl(paste0(suffix, "$"), pkg)) {
        return(TRUE)
      }
    }
  }

  FALSE
}

#' Validate Package Name Format
#'
#' Checks if package name follows R package naming rules:
#' - Starts with a letter
#' - Contains only letters, numbers, and dots
#' - Does not start or end with a dot
#'
#' @param pkg Character. Package name to validate.
#'
#' @return Logical. TRUE if valid, FALSE otherwise.
#'
#' @keywords internal
is_valid_package_name <- function(pkg) {

  # Must start with letter, contain only letters/numbers/dots
  if (!grepl("^[a-zA-Z][a-zA-Z0-9.]*$", pkg)) {
    return(FALSE)
  }

  # Cannot start or end with dot
  if (grepl("^\\.", pkg) || grepl("\\.$", pkg)) {
    return(FALSE)
  }

  TRUE
}

#' Get Current Package Name
#'
#' Extracts package name from DESCRIPTION file to avoid self-reference.
#'
#' @param path Character. Path to project root.
#'
#' @return Character. Package name, or NULL if not found.
#'
#' @keywords internal
get_current_package_name <- function(path = ".") {

  desc_file <- file.path(path, "DESCRIPTION")

  if (!file.exists(desc_file)) {
    return(NULL)
  }

  tryCatch({
    d <- desc::desc(desc_file)
    d$get("Package")
  }, error = function(e) {
    NULL
  })
}

#' Add Current Package to Placeholders
#'
#' Dynamically adds the current package name to the placeholder list
#' to prevent self-referencing in DESCRIPTION.
#'
#' @param path Character. Path to project root.
#'
#' @return Character vector. Updated PLACEHOLDER_PACKAGES.
#'
#' @keywords internal
get_extended_placeholders <- function(path = ".") {

  placeholders <- PLACEHOLDER_PACKAGES

  current_pkg <- get_current_package_name(path)

  if (!is.null(current_pkg) && nchar(current_pkg) > 0) {
    placeholders <- c(placeholders, current_pkg)
  }

  placeholders
}
