# Tests for Sync Functions

test_that("create_renv_lock creates valid JSON structure", {
  skip_on_cran()

  temp_dir <- withr::local_tempdir()

  result <- create_renv_lock(
    r_version = "4.4.0",
    cran_url = "https://cloud.r-project.org",
    path = temp_dir
  )

  expect_true(result)
  expect_true(file.exists(file.path(temp_dir, "renv.lock")))

  lock_data <- jsonlite::fromJSON(
    file.path(temp_dir, "renv.lock"),
    simplifyVector = FALSE
  )

  expect_true("R" %in% names(lock_data))
  expect_true("Packages" %in% names(lock_data))
  expect_equal(lock_data$R$Version, "4.4.0")
})

test_that("create_renv_lock uses current R version by default", {
  skip_on_cran()

  temp_dir <- withr::local_tempdir()

  result <- create_renv_lock(path = temp_dir)

  expect_true(result)

  lock_data <- jsonlite::fromJSON(
    file.path(temp_dir, "renv.lock"),
    simplifyVector = FALSE
  )

  expected_version <- paste(R.version$major, R.version$minor, sep = ".")
  expect_equal(lock_data$R$Version, expected_version)
})

test_that("remove_from_renv_lock removes packages", {
  skip_on_cran()

  temp_dir <- withr::local_tempdir()

  lock_data <- list(
    R = list(Version = "4.4.0"),
    Packages = list(
      dplyr = list(Package = "dplyr", Version = "1.1.0"),
      ggplot2 = list(Package = "ggplot2", Version = "3.4.0"),
      tidyr = list(Package = "tidyr", Version = "1.3.0")
    )
  )

  jsonlite::write_json(
    lock_data,
    file.path(temp_dir, "renv.lock"),
    pretty = TRUE,
    auto_unbox = TRUE
  )

  removed <- remove_from_renv_lock(c("dplyr", "tidyr"), path = temp_dir)

  expect_equal(sort(removed), c("dplyr", "tidyr"))

  updated_lock <- jsonlite::fromJSON(
    file.path(temp_dir, "renv.lock"),
    simplifyVector = FALSE
  )

  expect_false("dplyr" %in% names(updated_lock$Packages))
  expect_false("tidyr" %in% names(updated_lock$Packages))
  expect_true("ggplot2" %in% names(updated_lock$Packages))
})

test_that("remove_from_renv_lock handles missing renv.lock", {
  temp_dir <- withr::local_tempdir()

  result <- remove_from_renv_lock(c("dplyr"), path = temp_dir)

  expect_equal(result, character(0))
})

test_that("remove_from_description removes packages", {
  skip_on_cran()

  temp_dir <- withr::local_tempdir()

  writeLines(
    c(
      "Package: testpkg",
      "Title: Test Package",
      "Version: 0.1.0",
      "Imports:",
      "    dplyr,",
      "    ggplot2,",
      "    tidyr"
    ),
    file.path(temp_dir, "DESCRIPTION")
  )

  removed <- remove_from_description(c("dplyr", "tidyr"), path = temp_dir)

  expect_true("dplyr" %in% removed)
  expect_true("tidyr" %in% removed)

  d <- desc::desc(file.path(temp_dir, "DESCRIPTION"))
  deps <- d$get_deps()
  imports <- deps[deps$type == "Imports", "package"]

  expect_false("dplyr" %in% imports)
  expect_false("tidyr" %in% imports)
  expect_true("ggplot2" %in% imports)
})

test_that("sync_packages dry_run does not modify files", {
  skip_on_cran()

  temp_dir <- withr::local_tempdir()

  writeLines(
    c(
      "Package: testpkg",
      "Title: Test Package",
      "Version: 0.1.0",
      "Imports:",
      "    dplyr,",
      "    unused_pkg"
    ),
    file.path(temp_dir, "DESCRIPTION")
  )

  r_dir <- file.path(temp_dir, "R")
  dir.create(r_dir)
  writeLines(
    "library(dplyr)\nlibrary(ggplot2)",
    file.path(r_dir, "test.R")
  )

  lock_data <- list(
    R = list(Version = "4.4.0"),
    Packages = list(
      dplyr = list(Package = "dplyr", Version = "1.1.0")
    )
  )
  jsonlite::write_json(
    lock_data,
    file.path(temp_dir, "renv.lock"),
    pretty = TRUE,
    auto_unbox = TRUE
  )

  desc_before <- readLines(file.path(temp_dir, "DESCRIPTION"))

  result <- sync_packages(path = temp_dir, dry_run = TRUE, verbose = FALSE)

  desc_after <- readLines(file.path(temp_dir, "DESCRIPTION"))

  expect_identical(desc_before, desc_after)
})
