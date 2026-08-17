tmp <- tempfile()
dir.create(tmp)
dir.create(file.path(tmp, "R"))

writeLines(
  c(
    'Package: testpkg',
    'Version: 0.1.0',
    'Imports: dplyr, ggplot2',
    'Suggests: testthat'
  ),
  file.path(tmp, "DESCRIPTION")
)
writeLines('library(dplyr)', file.path(tmp, "R", "code.R"))
writeLines(
  '{
    "R": {"Version": "4.6.0"},
    "Packages": {
      "dplyr": {"Package": "dplyr", "Version": "1.1.0", "Source": "Repository"},
      "ggplot2": {"Package": "ggplot2", "Version": "3.5.0", "Source": "Repository"}
    }
  }',
  file.path(tmp, "renv.lock")
)

status <- report_packages(path = tmp)
expect_true(is.data.frame(status), info = 'report_packages returns a data frame')
expect_true(all(c("package", "in_code", "in_description", "status") %in% names(status)),
  info = 'report_packages includes the documented columns')
expect_true("dplyr" %in% status$package, info = 'a package used in code is reported')
expect_equal(
  status$status[status$package == "ggplot2"],
  factor("unused", levels = levels(status$status)),
  info = 'a declared-but-unused package is flagged unused'
)

removed <- clean_description(strict = TRUE, path = tmp)
expect_true(is.character(removed),
  info = 'clean_description returns a character vector of removed packages')
expect_true("ggplot2" %in% removed,
  info = 'clean_description removes the unused declared package')

unlink(tmp, recursive = TRUE)
