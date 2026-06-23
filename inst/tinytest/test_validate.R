# Tests for Package Source Validation Functions

# Skip network tests unless NOT_CRAN is set AND a real CRAN mirror is
# configured. R CMD check sets NOT_CRAN=true without a mirror (repos
# CRAN = '@CRAN@'); the mirror check stops the CRAN/Bioc/GitHub probes
# from erroring under check while still running them in dev/CI.
not_on_cran <- identical(Sys.getenv('NOT_CRAN'), 'true') &&
  !is.null(getOption('repos')[['CRAN']]) &&
  nzchar(getOption('repos')[['CRAN']]) &&
  !identical(unname(getOption('repos')[['CRAN']]), '@CRAN@')

# is_installable returns correct structure
local({
  result <- is_installable('base', check_cran = FALSE, check_bioc = FALSE,
                           check_github = FALSE)
  expect_equal(typeof(result), 'list', info = 'result is list')
  expect_equal(names(result), c('installable', 'source', 'package'),
               info = 'has expected names')
  expect_equal(typeof(result$installable), 'logical',
               info = 'installable is logical')
  expect_equal(typeof(result$source), 'character',
               info = 'source is character')
  expect_equal(typeof(result$package), 'character',
               info = 'package is character')
})

# is_installable finds CRAN packages
if (not_on_cran) local({
  result <- is_installable('jsonlite', check_bioc = FALSE,
                           check_github = FALSE)
  expect_true(result$installable, info = 'jsonlite installable')
  expect_equal(result$source, 'CRAN', info = 'jsonlite source is CRAN')
  expect_equal(result$package, 'jsonlite', info = 'jsonlite name preserved')
})

# is_installable returns FALSE for non-existent packages
if (not_on_cran) local({
  result <- is_installable('NonExistentPackage12345xyz',
                           check_cran = TRUE,
                           check_bioc = FALSE,
                           check_github = FALSE)
  expect_false(result$installable, info = 'fake pkg not installable')
  expect_true(is.na(result$source), info = 'fake pkg source NA')
})

# validate_cran works for known packages
if (not_on_cran) local({
  expect_true(zzrenvcheck:::validate_cran('jsonlite'),
              info = 'validate_cran: jsonlite TRUE')
  expect_false(zzrenvcheck:::validate_cran('NonExistentPackage12345xyz'),
               info = 'validate_cran: fake FALSE')
})

# validate_github requires slash in package name
expect_false(zzrenvcheck:::validate_github('dplyr'),
             info = 'validate_github: dplyr no slash')
expect_false(zzrenvcheck:::validate_github('tidyverse'),
             info = 'validate_github: tidyverse no slash')

# check_installable returns data frame
if (not_on_cran) local({
  result <- check_installable(
    c('jsonlite', 'NonExistent12345'),
    check_bioc = FALSE,
    check_github = FALSE,
    progress = FALSE
  )
  expect_inherits(result, 'data.frame',
                  info = 'check_installable returns data.frame')
  expect_equal(names(result), c('package', 'installable', 'source'),
               info = 'expected column names')
  expect_equal(nrow(result), 2, info = '2 rows for 2 inputs')
})

# check_installable handles empty input
local({
  result <- check_installable(character(0), progress = FALSE)
  expect_inherits(result, 'data.frame',
                  info = 'empty input returns data.frame')
  expect_equal(nrow(result), 0, info = 'empty input returns 0 rows')
})
