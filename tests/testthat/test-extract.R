# Tests for Package Extraction Functions

# Helper function for testing
extract_packages_from_file_lines <- function(lines, skip_comments = TRUE) {
  if (skip_comments) {
    is_roxygen <- grepl("^\\s*#'", lines)
    is_comment <- grepl("^\\s*#", lines) & !is_roxygen
    lines[is_comment] <- ""
  }

  packages <- character(0)
  packages <- c(packages, extract_library_calls(lines))
  packages <- c(packages, extract_require_calls(lines))
  packages <- c(packages, extract_namespace_calls(lines))
  packages <- c(packages, extract_roxygen_imports(lines))

  packages
}

test_that("extract_library_calls finds library() calls", {
  lines <- c(
    "library(dplyr)",
    "library('ggplot2')",
    'library("tidyr")'
  )

  pkgs <- extract_library_calls(lines)

  expect_true("dplyr" %in% pkgs)
  expect_true("ggplot2" %in% pkgs)
  expect_true("tidyr" %in% pkgs)
})

test_that("extract_require_calls finds require() calls", {
  lines <- c(
    "require(dplyr)",
    "require('ggplot2')",
    'require("tidyr")'
  )

  pkgs <- extract_require_calls(lines)

  expect_true("dplyr" %in% pkgs)
  expect_true("ggplot2" %in% pkgs)
  expect_true("tidyr" %in% pkgs)
})

test_that("extract_namespace_calls finds pkg:: calls", {
  lines <- c(
    "dplyr::filter(data, x > 0)",
    "result <- ggplot2::ggplot()",
    "tidyr::pivot_longer(df)"
  )

  pkgs <- extract_namespace_calls(lines)

  expect_true("dplyr" %in% pkgs)
  expect_true("ggplot2" %in% pkgs)
  expect_true("tidyr" %in% pkgs)
})

test_that("extract_roxygen_imports finds @importFrom", {
  lines <- c(
    "#' @importFrom dplyr filter",
    "#' @importFrom ggplot2 ggplot aes"
  )

  pkgs <- extract_roxygen_imports(lines)

  expect_true("dplyr" %in% pkgs)
  expect_true("ggplot2" %in% pkgs)
})

test_that("extract_roxygen_imports finds @import", {
  lines <- c(
    "#' @import dplyr",
    "#' @import ggplot2"
  )

  pkgs <- extract_roxygen_imports(lines)

  expect_true("dplyr" %in% pkgs)
  expect_true("ggplot2" %in% pkgs)
})

test_that("extract ignores commented code", {
  lines <- c(
    "library(dplyr)",
    "# library(ggplot2)",
    "  # library(tidyr)"
  )

  # Extract without filtering comments
  pkgs_with <- extract_packages_from_file_lines(lines, skip_comments = FALSE)

  # Extract with filtering comments
  pkgs_without <- extract_packages_from_file_lines(lines, skip_comments = TRUE)

  expect_true("dplyr" %in% pkgs_without)
  expect_false("ggplot2" %in% pkgs_without)
  expect_false("tidyr" %in% pkgs_without)
})
