# Tests for Package Name Cleaning and Validation

test_that("clean_package_names removes base packages", {
  packages <- c("dplyr", "base", "utils", "ggplot2", "stats")

  cleaned <- clean_package_names(packages)

  expect_true("dplyr" %in% cleaned)
  expect_true("ggplot2" %in% cleaned)
  expect_false("base" %in% cleaned)
  expect_false("utils" %in% cleaned)
  expect_false("stats" %in% cleaned)
})

test_that("clean_package_names removes short names", {
  packages <- c("dplyr", "my", "an", "if", "ggplot2")

  cleaned <- clean_package_names(packages)

  expect_true("dplyr" %in% cleaned)
  expect_true("ggplot2" %in% cleaned)
  expect_false("my" %in% cleaned)
  expect_false("an" %in% cleaned)
  expect_false("if" %in% cleaned)
})

test_that("clean_package_names validates format", {
  packages <- c("dplyr", ".invalid", "invalid.", "123pkg", "valid.pkg")

  cleaned <- clean_package_names(packages)

  expect_true("dplyr" %in% cleaned)
  expect_true("valid.pkg" %in% cleaned)
  expect_false(".invalid" %in% cleaned)
  expect_false("invalid." %in% cleaned)
  expect_false("123pkg" %in% cleaned)
})

test_that("clean_package_names removes placeholder names", {
  packages <- c("dplyr", "package", "myproject", "foo", "bar")

  cleaned <- clean_package_names(packages)

  expect_true("dplyr" %in% cleaned)
  expect_false("package" %in% cleaned)
  expect_false("myproject" %in% cleaned)
  expect_false("foo" %in% cleaned)
  expect_false("bar" %in% cleaned)
})

test_that("clean_package_names removes generic words", {
  packages <- c("dplyr", "my", "your", "file", "path", "name")

  cleaned <- clean_package_names(packages)

  expect_true("dplyr" %in% cleaned)
  expect_false("my" %in% cleaned)
  expect_false("your" %in% cleaned)
  expect_false("file" %in% cleaned)
  expect_false("path" %in% cleaned)
  expect_false("name" %in% cleaned)
})

test_that("clean_package_names deduplicates", {
  packages <- c("dplyr", "dplyr", "ggplot2", "dplyr")

  cleaned <- clean_package_names(packages)

  expect_equal(sum(cleaned == "dplyr"), 1)
  expect_equal(length(cleaned), 2)
})

test_that("clean_package_names sorts alphabetically", {
  packages <- c("zzz", "aaa", "mmm")

  cleaned <- clean_package_names(packages)

  expect_equal(cleaned, c("aaa", "mmm", "zzz"))
})

test_that("is_valid_package_name works correctly", {
  expect_true(is_valid_package_name("dplyr"))
  expect_true(is_valid_package_name("ggplot2"))
  expect_true(is_valid_package_name("data.table"))

  expect_false(is_valid_package_name(".invalid"))
  expect_false(is_valid_package_name("invalid."))
  expect_false(is_valid_package_name("123invalid"))
  expect_false(is_valid_package_name("invalid-name"))
})

test_that("is_generic_word identifies common words", {
  expect_true(is_generic_word("my"))
  expect_true(is_generic_word("your"))
  expect_true(is_generic_word("file"))
  expect_true(is_generic_word("path"))

  expect_false(is_generic_word("dplyr"))
  expect_false(is_generic_word("ggplot2"))
})
