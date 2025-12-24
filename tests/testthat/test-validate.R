# Tests for Package Source Validation Functions

test_that("is_installable returns correct structure", {
  result <- is_installable("base", check_cran = FALSE, check_bioc = FALSE,
                           check_github = FALSE)

  expect_type(result, "list")
  expect_named(result, c("installable", "source", "package"))
  expect_type(result$installable, "logical")
  expect_type(result$source, "character")
  expect_type(result$package, "character")
})

test_that("is_installable finds CRAN packages", {
  skip_on_cran()
  skip_if_offline()

  result <- is_installable("jsonlite", check_bioc = FALSE, check_github = FALSE)

  expect_true(result$installable)
  expect_equal(result$source, "CRAN")
  expect_equal(result$package, "jsonlite")
})

test_that("is_installable returns FALSE for non-existent packages", {
  skip_on_cran()
  skip_if_offline()

  result <- is_installable("NonExistentPackage12345xyz",
                           check_cran = TRUE,
                           check_bioc = FALSE,
                           check_github = FALSE)

  expect_false(result$installable)
  expect_true(is.na(result$source))
})

test_that("validate_cran works for known packages", {
  skip_on_cran()
  skip_if_offline()

  expect_true(validate_cran("jsonlite"))
  expect_false(validate_cran("NonExistentPackage12345xyz"))
})

test_that("validate_github requires slash in package name", {
  expect_false(validate_github("dplyr"))
  expect_false(validate_github("tidyverse"))
})

test_that("check_installable returns data frame", {
  skip_on_cran()
  skip_if_offline()

  result <- check_installable(
    c("jsonlite", "NonExistent12345"),
    check_bioc = FALSE,
    check_github = FALSE,
    progress = FALSE
  )

  expect_s3_class(result, "data.frame")
  expect_named(result, c("package", "installable", "source"))
  expect_equal(nrow(result), 2)
})

test_that("check_installable handles empty input", {
  result <- check_installable(character(0), progress = FALSE)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})
