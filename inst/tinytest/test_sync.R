# Tests for Sync Functions

# Equivalent of testthat::skip_on_cran(): only run network/heavy tests
# when NOT_CRAN is set, which is the standard CRAN-set guard.
not_on_cran <- identical(Sys.getenv('NOT_CRAN'), 'true')

# create_renv_lock creates valid JSON structure
if (not_on_cran) local({
  temp_dir <- withr::local_tempdir()
  result <- create_renv_lock(
    r_version = '4.4.0',
    cran_url = 'https://cloud.r-project.org',
    path = temp_dir
  )
  expect_true(result, info = 'create_renv_lock returns TRUE')
  expect_true(file.exists(file.path(temp_dir, 'renv.lock')),
              info = 'renv.lock file exists')
  lock_data <- jsonlite::fromJSON(
    file.path(temp_dir, 'renv.lock'),
    simplifyVector = FALSE
  )
  expect_true('R' %in% names(lock_data), info = 'lock has R section')
  expect_true('Packages' %in% names(lock_data), info = 'lock has Packages section')
  expect_equal(lock_data$R$Version, '4.4.0', info = 'R version recorded')
})

# create_renv_lock uses current R version by default
if (not_on_cran) local({
  temp_dir <- withr::local_tempdir()
  result <- create_renv_lock(path = temp_dir)
  expect_true(result, info = 'default R version returns TRUE')
  lock_data <- jsonlite::fromJSON(
    file.path(temp_dir, 'renv.lock'),
    simplifyVector = FALSE
  )
  expected_version <- paste(R.version$major, R.version$minor, sep = '.')
  expect_equal(lock_data$R$Version, expected_version,
               info = 'default R version matches current')
})

# remove_from_renv_lock removes packages
if (not_on_cran) local({
  temp_dir <- withr::local_tempdir()
  lock_data <- list(
    R = list(Version = '4.4.0'),
    Packages = list(
      dplyr = list(Package = 'dplyr', Version = '1.1.0'),
      ggplot2 = list(Package = 'ggplot2', Version = '3.4.0'),
      tidyr = list(Package = 'tidyr', Version = '1.3.0')
    )
  )
  jsonlite::write_json(
    lock_data,
    file.path(temp_dir, 'renv.lock'),
    pretty = TRUE,
    auto_unbox = TRUE
  )
  removed <- remove_from_renv_lock(c('dplyr', 'tidyr'), path = temp_dir)
  expect_equal(sort(removed), c('dplyr', 'tidyr'),
               info = 'removed names returned')
  updated_lock <- jsonlite::fromJSON(
    file.path(temp_dir, 'renv.lock'),
    simplifyVector = FALSE
  )
  expect_false('dplyr' %in% names(updated_lock$Packages),
               info = 'dplyr removed from lockfile')
  expect_false('tidyr' %in% names(updated_lock$Packages),
               info = 'tidyr removed from lockfile')
  expect_true('ggplot2' %in% names(updated_lock$Packages),
              info = 'ggplot2 retained in lockfile')
})

# remove_from_renv_lock handles missing renv.lock
local({
  temp_dir <- withr::local_tempdir()
  result <- remove_from_renv_lock(c('dplyr'), path = temp_dir)
  expect_equal(result, character(0),
               info = 'missing lockfile returns empty character')
})

# remove_from_description removes packages
if (not_on_cran) local({
  temp_dir <- withr::local_tempdir()
  writeLines(
    c(
      'Package: testpkg',
      'Title: Test Package',
      'Version: 0.1.0',
      'Imports:',
      '    dplyr,',
      '    ggplot2,',
      '    tidyr'
    ),
    file.path(temp_dir, 'DESCRIPTION')
  )
  removed <- zzrenvcheck:::remove_from_description(c('dplyr', 'tidyr'), path = temp_dir)
  expect_true('dplyr' %in% removed, info = 'dplyr in removed')
  expect_true('tidyr' %in% removed, info = 'tidyr in removed')
  d <- desc::desc(file.path(temp_dir, 'DESCRIPTION'))
  deps <- d$get_deps()
  imports <- deps[deps$type == 'Imports', 'package']
  expect_false('dplyr' %in% imports, info = 'dplyr removed from imports')
  expect_false('tidyr' %in% imports, info = 'tidyr removed from imports')
  expect_true('ggplot2' %in% imports, info = 'ggplot2 retained in imports')
})

# resolve_transitive_deps returns named character vector
if (not_on_cran) local({
  result <- resolve_transitive_deps('cli')
  expect_true(is.character(result), info = 'result is character')
  expect_true(!is.null(names(result)), info = 'result has names')
  expect_true('cli' %in% names(result), info = 'direct package included')
  expect_true(length(result) >= 1L, info = 'at least the direct package returned')
  expect_true(all(nchar(result) > 0), info = 'all versions non-empty')
})

# resolve_transitive_deps includes transitive deps
if (not_on_cran) local({
  result <- resolve_transitive_deps('ggplot2')
  expect_true('ggplot2' %in% names(result), info = 'ggplot2 direct dep present')
  expect_true('rlang' %in% names(result), info = 'rlang transitive dep present')
  expect_true('scales' %in% names(result), info = 'scales transitive dep present')
})

# resolve_transitive_deps skips non-CRAN packages
if (not_on_cran) local({
  result <- resolve_transitive_deps(c('cli', 'NonExistentPkg12345xyz'))
  expect_true('cli' %in% names(result), info = 'CRAN package resolved')
  expect_false('NonExistentPkg12345xyz' %in% names(result),
               info = 'non-CRAN package excluded')
})

# resolve_transitive_deps returns empty for all non-CRAN input
if (not_on_cran) local({
  result <- resolve_transitive_deps('NonExistentPkg12345xyz')
  expect_equal(length(result), 0L, info = 'empty result for non-CRAN only input')
})

# resolve_transitive_deps reuses provided db
if (not_on_cran) local({
  db <- available.packages()
  result <- resolve_transitive_deps('cli', db = db)
  expect_true('cli' %in% names(result), info = 'works with provided db')
})

# add_with_deps_to_renv_lock adds direct and transitive packages
if (not_on_cran) local({
  temp_dir <- withr::local_tempdir()
  create_renv_lock(r_version = '4.4.0', path = temp_dir)
  success <- add_with_deps_to_renv_lock('cli', path = temp_dir)
  expect_true(success, info = 'add_with_deps returns TRUE')
  lock_data <- jsonlite::fromJSON(
    file.path(temp_dir, 'renv.lock'),
    simplifyVector = FALSE
  )
  expect_true('cli' %in% names(lock_data$Packages),
              info = 'cli direct dep in lockfile')
  expect_true(length(lock_data$Packages) >= 1L,
              info = 'at least one package in lockfile')
  cli_entry <- lock_data$Packages[['cli']]
  expect_equal(cli_entry$Source, 'Repository', info = 'Source is Repository')
  expect_equal(cli_entry$Repository, 'CRAN', info = 'Repository is CRAN')
  expect_true(nchar(cli_entry$Version) > 0, info = 'Version non-empty')
})

# add_with_deps_to_renv_lock handles missing renv.lock
if (not_on_cran) local({
  temp_dir <- withr::local_tempdir()
  success <- add_with_deps_to_renv_lock('cli', path = temp_dir)
  expect_false(success, info = 'returns FALSE when renv.lock missing')
})

# sync_packages dry_run does not modify files
if (not_on_cran) local({
  temp_dir <- withr::local_tempdir()
  writeLines(
    c(
      'Package: testpkg',
      'Title: Test Package',
      'Version: 0.1.0',
      'Imports:',
      '    dplyr,',
      '    unused_pkg'
    ),
    file.path(temp_dir, 'DESCRIPTION')
  )
  r_dir <- file.path(temp_dir, 'R')
  dir.create(r_dir)
  writeLines(
    'library(dplyr)\nlibrary(ggplot2)',
    file.path(r_dir, 'test.R')
  )
  lock_data <- list(
    R = list(Version = '4.4.0'),
    Packages = list(
      dplyr = list(Package = 'dplyr', Version = '1.1.0')
    )
  )
  jsonlite::write_json(
    lock_data,
    file.path(temp_dir, 'renv.lock'),
    pretty = TRUE,
    auto_unbox = TRUE
  )
  desc_before <- readLines(file.path(temp_dir, 'DESCRIPTION'))
  result <- sync_packages(path = temp_dir, dry_run = TRUE, verbose = FALSE)
  desc_after <- readLines(file.path(temp_dir, 'DESCRIPTION'))
  expect_identical(desc_before, desc_after,
                   info = 'dry_run leaves DESCRIPTION unchanged')
})
