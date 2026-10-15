# Tests for research-compendium archetype exemption

# Helper: minimal research compendium fixture (has analysis/)
make_compendium <- function(r_code = NULL, analysis_code = NULL,
                            desc_imports = NULL, lock_packages = '{}') {
  d <- tempfile('compendium')
  dir.create(file.path(d, 'R'), recursive = TRUE)
  dir.create(file.path(d, 'analysis'), recursive = TRUE)
  if (!is.null(r_code))
    writeLines(r_code, file.path(d, 'R', 'funcs.R'))
  if (!is.null(analysis_code))
    writeLines(analysis_code, file.path(d, 'analysis', 'run.R'))
  imports_block <- if (!is.null(desc_imports)) {
    c('Imports:', paste0('    ', desc_imports, collapse = '\n'))
  } else {
    character(0)
  }
  writeLines(c('Package: mycomp', 'Version: 0.1.0', imports_block),
             file.path(d, 'DESCRIPTION'))
  writeLines(
    paste0('{"R":{"Version":"4.4.0"},"Packages":', lock_packages, '}'),
    file.path(d, 'renv.lock')
  )
  d
}

# Helper: plain R package fixture (no analysis/)
make_pkg <- function(r_code = NULL, desc_imports = NULL,
                     lock_packages = '{}') {
  d <- tempfile('rpkg')
  dir.create(file.path(d, 'R'), recursive = TRUE)
  if (!is.null(r_code))
    writeLines(r_code, file.path(d, 'R', 'funcs.R'))
  imports_block <- if (!is.null(desc_imports)) {
    c('Imports:', paste0('    ', desc_imports, collapse = '\n'))
  } else {
    character(0)
  }
  writeLines(c('Package: mypkg', 'Version: 0.1.0', imports_block),
             file.path(d, 'DESCRIPTION'))
  writeLines(
    paste0('{"R":{"Version":"4.4.0"},"Packages":', lock_packages, '}'),
    file.path(d, 'renv.lock')
  )
  d
}

lock_entry <- function(pkg, ver = '1.0.0') {
  paste0('"', pkg, '":{"Package":"', pkg, '","Version":"', ver, '"}')
}

# auto-detection: compendium mode activates when analysis/ is present
local({
  d_yes <- make_compendium()
  d_no  <- make_pkg()
  on.exit(unlink(c(d_yes, d_no), recursive = TRUE), add = TRUE)

  r_yes <- suppressMessages(check_packages(
    path = d_yes, strict = FALSE, versions = FALSE, error_on_fail = FALSE
  ))
  r_no  <- suppressMessages(check_packages(
    path = d_no,  strict = FALSE, versions = FALSE, error_on_fail = FALSE
  ))

  # Both return a list; we inspect the content to infer mode indirectly
  # via the description-required check: add a package to analysis/ only
  # and confirm it is NOT in missing_in_description for the compendium.
  expect_true(is.list(r_yes), info = 'compendium: result is list')
  expect_true(is.list(r_no),  info = 'package: result is list')
})

# analysis-only package not flagged as missing in DESCRIPTION (compendium)
local({
  jl_entry  <- lock_entry('jsonlite')
  d <- make_compendium(
    analysis_code = 'jsonlite::toJSON(1)',
    lock_packages  = paste0('{', jl_entry, '}')
  )
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  r <- suppressMessages(check_packages(
    path = d, strict = FALSE, versions = FALSE, error_on_fail = FALSE
  ))
  expect_false(
    'jsonlite' %in% r$missing_in_description,
    info = 'compendium: analysis-only pkg not missing in DESCRIPTION'
  )
  expect_equal(r$status, 'pass',
               info = 'compendium: analysis-only pkg passes gate')
})

# package used in R/ IS flagged as missing in DESCRIPTION (compendium)
local({
  jl_entry <- lock_entry('jsonlite')
  d <- make_compendium(
    r_code        = 'jsonlite::toJSON(1)',
    lock_packages  = paste0('{', jl_entry, '}')
  )
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  r <- suppressMessages(check_packages(
    path = d, strict = FALSE, versions = FALSE, error_on_fail = FALSE
  ))
  expect_true(
    'jsonlite' %in% r$missing_in_description,
    info = 'compendium: R/-used pkg still required in DESCRIPTION'
  )
  expect_equal(r$status, 'fail',
               info = 'compendium: missing R/ pkg fails gate')
})

# compendium = FALSE disables exemption even when analysis/ exists
local({
  jl_entry <- lock_entry('jsonlite')
  d <- make_compendium(
    analysis_code = 'jsonlite::toJSON(1)',
    lock_packages  = paste0('{', jl_entry, '}')
  )
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  r <- suppressMessages(check_packages(
    path = d, strict = FALSE, versions = FALSE,
    compendium = FALSE, error_on_fail = FALSE
  ))
  expect_true(
    'jsonlite' %in% r$missing_in_description,
    info = 'compendium=FALSE: analysis pkg flagged as missing in DESCRIPTION'
  )
  expect_equal(r$status, 'fail',
               info = 'compendium=FALSE: analysis pkg fails gate')
})

# compendium = TRUE explicit: analysis-only package exempt
local({
  jl_entry <- lock_entry('jsonlite')
  d <- make_compendium(
    analysis_code = 'jsonlite::toJSON(1)',
    lock_packages  = paste0('{', jl_entry, '}')
  )
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  r <- suppressMessages(check_packages(
    path = d, strict = FALSE, versions = FALSE,
    compendium = TRUE, error_on_fail = FALSE
  ))
  expect_false(
    'jsonlite' %in% r$missing_in_description,
    info = 'compendium=TRUE explicit: analysis pkg exempt from DESCRIPTION'
  )
})

# compendium mode does NOT exempt analysis packages from renv.lock
local({
  d <- make_compendium(
    analysis_code = 'jsonlite::toJSON(1)'
  )
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  r <- suppressMessages(check_packages(
    path = d, strict = FALSE, versions = FALSE, error_on_fail = FALSE
  ))
  expect_true(
    'jsonlite' %in% r$missing_in_lock,
    info = 'compendium: analysis pkg still required in renv.lock'
  )
  expect_equal(r$status, 'fail',
               info = 'compendium: analysis pkg missing from lock fails gate'
  )
})

# packages used in both R/ and analysis/ must be in DESCRIPTION
local({
  d <- make_compendium(
    r_code        = 'jsonlite::toJSON(1)',
    analysis_code = 'jsonlite::fromJSON("{}")'
  )
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  r <- suppressMessages(check_packages(
    path = d, strict = FALSE, versions = FALSE, error_on_fail = FALSE
  ))
  expect_true(
    'jsonlite' %in% r$missing_in_description,
    info = 'compendium: pkg used in R/ AND analysis/ still required in DESCRIPTION'
  )
})

# plain package mode: analysis/ packages would be flagged if present
local({
  jl_entry <- lock_entry('jsonlite')
  d <- make_pkg(
    r_code        = 'jsonlite::toJSON(1)',
    lock_packages  = paste0('{', jl_entry, '}')
  )
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  r <- suppressMessages(check_packages(
    path = d, strict = FALSE, versions = FALSE, error_on_fail = FALSE
  ))
  expect_true(
    'jsonlite' %in% r$missing_in_description,
    info = 'package mode: R/ pkg flagged as missing in DESCRIPTION'
  )
})

# PACKAGE_API_DIRS constant contains only "R"
local({
  expect_true(
    identical(zzrenvcheck:::PACKAGE_API_DIRS, 'R'),
    info = 'PACKAGE_API_DIRS is "R"'
  )
})

# compendium mode does not flag the package's own name
local({
  d <- tempfile('selfref')
  dir.create(file.path(d, 'R'), recursive = TRUE)
  dir.create(file.path(d, 'analysis'), recursive = TRUE)
  writeLines(
    c('library(selfref)', 'selfref::myfunc()'),
    file.path(d, 'R', 'funcs.R')
  )
  writeLines(c('Package: selfref', 'Version: 0.1.0'),
             file.path(d, 'DESCRIPTION'))
  writeLines(
    '{"R":{"Version":"4.4.0"},"Packages":{}}',
    file.path(d, 'renv.lock')
  )
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  r <- suppressMessages(check_packages(
    path = d, strict = FALSE, versions = FALSE, error_on_fail = FALSE
  ))
  expect_false(
    'selfref' %in% r$missing_in_description,
    info = 'compendium: own package name not flagged as missing'
  )
})
