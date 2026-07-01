# Tests for cross-document version synchronisation

# version_satisfies: no constraint is always satisfied
local({
  vs <- zzrenvcheck:::version_satisfies
  expect_true(vs('2.0.0', '*'), info = 'wildcard satisfied')
  expect_true(vs('2.0.0', ''), info = 'empty constraint satisfied')
  expect_true(vs('2.0.0', NA_character_), info = 'NA constraint satisfied')
  expect_true(vs(NA_character_, '>= 1.0.0'), info = 'NA version satisfied')
})

# version_satisfies: operator semantics
local({
  vs <- zzrenvcheck:::version_satisfies
  expect_true(vs('2.0.0', '>= 1.0.0'), info = '2.0.0 >= 1.0.0')
  expect_false(vs('1.1.0', '>= 2.0.0'), info = '1.1.0 not >= 2.0.0')
  expect_true(vs('1.0.0', '>= 1.0.0'), info = 'equal satisfies >=')
  expect_false(vs('1.0.0', '> 1.0.0'), info = 'equal fails >')
  expect_true(vs('1.0.0', '<= 1.0.0'), info = 'equal satisfies <=')
  expect_false(vs('2.0.0', '< 1.0.0'), info = '2.0.0 not < 1.0.0')
  expect_true(vs('1.1.0', '== 1.1.0'), info = 'exact equality')
  expect_false(vs('1.1.0', '== 1.2.0'), info = 'exact inequality')
})

# version_satisfies: unparseable constraint is treated as satisfied
local({
  vs <- zzrenvcheck:::version_satisfies
  expect_true(vs('1.0.0', 'github::owner/repo'),
              info = 'non-standard constraint not flagged')
})

# parse_renv_lock_versions returns package and version columns
local({
  temp_dir <- tempfile()
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  lock <- file.path(temp_dir, 'renv.lock')
  writeLines(c(
    '{',
    '  "R": {"Version": "4.4.0"},',
    '  "Packages": {',
    '    "dplyr": {"Package": "dplyr", "Version": "1.1.0"},',
    '    "ggplot2": {"Package": "ggplot2", "Version": "3.5.0"}',
    '  }',
    '}'
  ), lock)
  res <- zzrenvcheck:::parse_renv_lock_versions(temp_dir)
  expect_equal(sort(res$package), c('dplyr', 'ggplot2'),
               info = 'lock package names')
  expect_equal(res$version[res$package == 'dplyr'], '1.1.0',
               info = 'lock version captured')
})

# extract_code_package_versions parses all four pin forms
local({
  temp_dir <- tempfile()
  dir.create(file.path(temp_dir, 'R'), recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  writeLines(c(
    "pak::pak('dplyr@1.1.0')",
    "renv::install('tidyr@1.3.0')",
    "remotes::install_version('purrr', version = '1.0.0')",
    "devtools::install_version('stringr', version = '1.5.0')"
  ), file.path(temp_dir, 'R', 'pins.R'))
  res <- extract_code_package_versions(dirs = 'R', path = temp_dir)
  expect_equal(res$version[res$package == 'dplyr'], '1.1.0',
               info = 'pak @-syntax')
  expect_equal(res$version[res$package == 'tidyr'], '1.3.0',
               info = 'renv @-syntax')
  expect_equal(res$version[res$package == 'purrr'], '1.0.0',
               info = 'remotes install_version')
  expect_equal(res$version[res$package == 'stringr'], '1.5.0',
               info = 'devtools install_version')
})

# extract_code_package_versions parses vector and multi-arg pins
local({
  temp_dir <- tempfile()
  dir.create(file.path(temp_dir, 'R'), recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  writeLines(c(
    "pak::pak(c('readr@2.1.0', 'tibble@3.2.0'))",
    "pak::pak('purrr@1.0.0', 'rlang@1.1.0')"
  ), file.path(temp_dir, 'R', 'pins.R'))
  res <- extract_code_package_versions(dirs = 'R', path = temp_dir)
  expect_equal(res$version[res$package == 'readr'], '2.1.0',
               info = 'vector pin first element')
  expect_equal(res$version[res$package == 'tibble'], '3.2.0',
               info = 'vector pin second element')
  expect_equal(res$version[res$package == 'purrr'], '1.0.0',
               info = 'multi-arg pin first element')
  expect_equal(res$version[res$package == 'rlang'], '1.1.0',
               info = 'multi-arg pin second element')
})

# extract_code_package_versions scans reproducibility files
local({
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  writeLines(
    "RUN R -e \"remotes::install_version('dplyr', version = '1.1.0')\"",
    file.path(temp_dir, 'Dockerfile')
  )
  writeLines("Rscript -e 'pak::pak(\"stringr@1.5.0\")'",
             file.path(temp_dir, 'install.sh'))
  res <- extract_code_package_versions(dirs = 'R', path = temp_dir)
  expect_equal(res$version[res$package == 'dplyr'], '1.1.0',
               info = 'Dockerfile install_version pin')
  expect_equal(res$version[res$package == 'stringr'], '1.5.0',
               info = 'install.sh pak pin')
})

# parse_description_remotes returns only version-like refs
local({
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  writeLines(c(
    'Package: smoke',
    'Version: 0.1.0',
    'Remotes:',
    '    tidyverse/dplyr@v1.3.0,',
    '    r-lib/devtools@main,',
    '    github::r-lib/rlang@1.1.0'
  ), file.path(temp_dir, 'DESCRIPTION'))
  res <- zzrenvcheck:::parse_description_remotes(temp_dir)
  expect_equal(res$version[res$package == 'dplyr'], '1.3.0',
               info = 'v-prefixed ref normalised')
  expect_equal(res$version[res$package == 'rlang'], '1.1.0',
               info = 'type prefix stripped, digit ref kept')
  expect_false('devtools' %in% res$package,
               info = 'branch ref (main) skipped')
})

# detect_version_conflicts labels distinct pin sources
local({
  desc <- data.frame(package = character(0), type = character(0),
                     version = character(0), stringsAsFactors = FALSE)
  lock <- data.frame(package = character(0), version = character(0),
                     stringsAsFactors = FALSE)
  pins <- data.frame(
    package = c('dplyr', 'dplyr'),
    version = c('1.1.0', '1.3.0'),
    source = c('code', 'DESCRIPTION Remotes'),
    stringsAsFactors = FALSE
  )
  res <- zzrenvcheck:::detect_version_conflicts(desc, lock, pins)
  expect_equal(nrow(res), 1, info = 'cross-source disagreement flagged')
  expect_true(grepl('DESCRIPTION Remotes', res$issue),
              info = 'issue names the Remotes source')
})

# extract_code_package_versions handles install_version arg shapes
local({
  temp_dir <- tempfile()
  dir.create(file.path(temp_dir, 'R'), recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  writeLines(c(
    "remotes::install_version('aaa', version = '1.0.0')",       # named version
    "devtools::install_version(package = 'bbb', version = '1.5.0')", # named package
    "remotes::install_version('ccc', '1.1.0')",                 # positional version
    "remotes::install_version('ddd',version='2.0.0')",          # no spaces
    "remotes::install_version( 'eee' , version = '3.0.0' )"     # extra spaces
  ), file.path(temp_dir, 'R', 'iv.R'))
  res <- extract_code_package_versions(dirs = 'R', path = temp_dir)
  expect_equal(res$version[res$package == 'aaa'], '1.0.0',
               info = 'named version arg')
  expect_equal(res$version[res$package == 'bbb'], '1.5.0',
               info = 'named package arg')
  expect_equal(res$version[res$package == 'ccc'], '1.1.0',
               info = 'positional version arg')
  expect_equal(res$version[res$package == 'ddd'], '2.0.0',
               info = 'no spaces around =')
  expect_equal(res$version[res$package == 'eee'], '3.0.0',
               info = 'extra spaces')
})

# extract_code_package_versions handles version-string and quote variants
local({
  temp_dir <- tempfile()
  dir.create(file.path(temp_dir, 'R'), recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  writeLines(c(
    'pak::pak("devver@1.1.0.9000")',      # four-component dev version
    "pak::pak('twocomp@1.1')",            # two-component
    'pak::pak("dblq@2.0.0")',             # double quotes
    "#' pak::pak('roxy@3.6.0')"           # roxygen example line
  ), file.path(temp_dir, 'R', 'v.R'))
  res <- extract_code_package_versions(dirs = 'R', path = temp_dir)
  expect_equal(res$version[res$package == 'devver'], '1.1.0.9000',
               info = 'four-component dev version')
  expect_equal(res$version[res$package == 'twocomp'], '1.1',
               info = 'two-component version')
  expect_equal(res$version[res$package == 'dblq'], '2.0.0',
               info = 'double-quoted pin')
  expect_equal(res$version[res$package == 'roxy'], '3.6.0',
               info = 'roxygen @examples pin captured')
})

# extract_code_package_versions ignores pak requirement/keyword refs
local({
  temp_dir <- tempfile()
  dir.create(file.path(temp_dir, 'R'), recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  writeLines(c(
    'pak::pak("req@>=1.6.0")',   # requirement, not an exact pin
    'pak::pak("kw@last")',       # keyword
    'pak::pak("kw2@current")'    # keyword
  ), file.path(temp_dir, 'R', 'req.R'))
  res <- extract_code_package_versions(dirs = 'R', path = temp_dir)
  expect_equal(nrow(res), 0,
               info = 'requirement and keyword refs are not exact pins')
})

# extract_code_package_versions ignores GitHub refs (owner/repo@branch)
local({
  temp_dir <- tempfile()
  dir.create(file.path(temp_dir, 'R'), recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  writeLines(c(
    "pak::pak('tidyverse/dplyr@main')",
    "library(ggplot2)"
  ), file.path(temp_dir, 'R', 'src.R'))
  res <- extract_code_package_versions(dirs = 'R', path = temp_dir)
  expect_equal(nrow(res), 0, info = 'github ref and plain library ignored')
})

# detect_version_conflicts: lock satisfies constraint -> no conflict
local({
  desc <- data.frame(package = 'dplyr', type = 'Imports',
                     version = '>= 1.0.0', stringsAsFactors = FALSE)
  lock <- data.frame(package = 'dplyr', version = '2.0.0',
                     stringsAsFactors = FALSE)
  code <- data.frame(package = character(0), version = character(0),
                     stringsAsFactors = FALSE)
  res <- zzrenvcheck:::detect_version_conflicts(desc, lock, code)
  expect_equal(nrow(res), 0, info = 'satisfied constraint not flagged')
})

# detect_version_conflicts: lock violates constraint -> conflict
local({
  desc <- data.frame(package = 'dplyr', type = 'Imports',
                     version = '>= 2.0.0', stringsAsFactors = FALSE)
  lock <- data.frame(package = 'dplyr', version = '1.1.0',
                     stringsAsFactors = FALSE)
  code <- data.frame(package = character(0), version = character(0),
                     stringsAsFactors = FALSE)
  res <- zzrenvcheck:::detect_version_conflicts(desc, lock, code)
  expect_equal(nrow(res), 1, info = 'violated constraint flagged')
  expect_true(grepl('violates', res$issue), info = 'issue mentions violation')
})

# detect_version_conflicts: code pin differs from lock -> conflict
local({
  desc <- data.frame(package = character(0), type = character(0),
                     version = character(0), stringsAsFactors = FALSE)
  lock <- data.frame(package = 'dplyr', version = '2.0.0',
                     stringsAsFactors = FALSE)
  code <- data.frame(package = 'dplyr', version = '1.1.0',
                     stringsAsFactors = FALSE)
  res <- zzrenvcheck:::detect_version_conflicts(desc, lock, code)
  expect_equal(nrow(res), 1, info = 'code vs lock mismatch flagged')
  expect_true(grepl('!=', res$issue), info = 'issue mentions mismatch')
})

# detect_version_conflicts: two code pins disagree -> conflict
local({
  desc <- data.frame(package = character(0), type = character(0),
                     version = character(0), stringsAsFactors = FALSE)
  lock <- data.frame(package = character(0), version = character(0),
                     stringsAsFactors = FALSE)
  code <- data.frame(package = c('dplyr', 'dplyr'),
                     version = c('1.1.0', '1.2.0'),
                     stringsAsFactors = FALSE)
  res <- zzrenvcheck:::detect_version_conflicts(desc, lock, code)
  expect_equal(nrow(res), 1, info = 'disagreeing code pins flagged')
  expect_true(grepl('disagree', res$issue), info = 'issue mentions disagreement')
})

# check_packages(error_on_fail = TRUE) raises a classed error on failure
local({
  temp_dir <- tempfile()
  dir.create(file.path(temp_dir, 'R'), recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  writeLines(c(
    'Package: smoke', 'Version: 0.1.0',
    'Imports:', '    dplyr (>= 2.0.0)'
  ), file.path(temp_dir, 'DESCRIPTION'))
  writeLines(
    '{"R":{"Version":"4.4.0"},"Packages":{"dplyr":{"Package":"dplyr","Version":"1.1.0"}}}',
    file.path(temp_dir, 'renv.lock')
  )
  err <- tryCatch(
    suppressMessages(check_packages(path = temp_dir, verbose = FALSE,
                                    error_on_fail = TRUE)),
    zzrenvcheck_validation_failure = function(e) e
  )
  expect_true(inherits(err, 'zzrenvcheck_validation_failure'),
              info = 'failure raises classed condition')
  expect_equal(err$result$status, 'fail',
               info = 'condition carries the result list')
})

# check_packages(error_on_fail = TRUE) returns normally when passing
local({
  temp_dir <- tempfile()
  dir.create(file.path(temp_dir, 'R'), recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  writeLines(c('Package: smoke', 'Version: 0.1.0'),
             file.path(temp_dir, 'DESCRIPTION'))
  writeLines('x <- 1', file.path(temp_dir, 'R', 'a.R'))
  r <- suppressMessages(check_packages(path = temp_dir, verbose = FALSE,
                                       versions = FALSE, error_on_fail = TRUE))
  expect_equal(r$status, 'pass',
               info = 'no error raised when validation passes')
})

# detect_version_conflicts: agreement across sources -> no conflict
local({
  desc <- data.frame(package = 'dplyr', type = 'Imports',
                     version = '>= 1.0.0', stringsAsFactors = FALSE)
  lock <- data.frame(package = 'dplyr', version = '1.1.0',
                     stringsAsFactors = FALSE)
  code <- data.frame(package = 'dplyr', version = '1.1.0',
                     stringsAsFactors = FALSE)
  res <- zzrenvcheck:::detect_version_conflicts(desc, lock, code)
  expect_equal(nrow(res), 0, info = 'consistent versions not flagged')
})
