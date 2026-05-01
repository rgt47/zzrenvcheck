# Tests for DESCRIPTION and renv.lock Parsing

test_that("parse_description_imports handles missing file", {
  temp_dir <- tempdir()

  result <- parse_description_imports(path = temp_dir)

  expect_equal(length(result), 0)
})

test_that("has_description detects DESCRIPTION file", {
  temp_dir <- tempfile()
  dir.create(temp_dir)

  expect_false(has_description(temp_dir))

  # Create minimal DESCRIPTION
  desc_file <- file.path(temp_dir, "DESCRIPTION")
  writeLines(c(
    "Package: testpkg",
    "Version: 0.1.0"
  ), desc_file)

  expect_true(has_description(temp_dir))

  unlink(temp_dir, recursive = TRUE)
})

test_that("has_renv_lock detects renv.lock file", {
  temp_dir <- tempfile()
  dir.create(temp_dir)

  expect_false(has_renv_lock(temp_dir))

  # Create minimal renv.lock
  lock_file <- file.path(temp_dir, "renv.lock")
  writeLines("{}", lock_file)

  expect_true(has_renv_lock(temp_dir))

  unlink(temp_dir, recursive = TRUE)
})
