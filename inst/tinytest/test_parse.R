# Tests for DESCRIPTION and renv.lock Parsing

# parse_description_imports handles missing file
local({
  temp_dir <- tempdir()
  result <- parse_description_imports(path = temp_dir)
  expect_equal(length(result), 0, info = 'missing DESCRIPTION returns empty')
})

# has_description detects DESCRIPTION file
local({
  temp_dir <- tempfile()
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  expect_false(zzrenvcheck:::has_description(temp_dir), info = 'has_description: empty dir')
  desc_file <- file.path(temp_dir, 'DESCRIPTION')
  writeLines(c(
    'Package: testpkg',
    'Version: 0.1.0'
  ), desc_file)
  expect_true(zzrenvcheck:::has_description(temp_dir), info = 'has_description: file present')
})

# has_renv_lock detects renv.lock file
local({
  temp_dir <- tempfile()
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  expect_false(zzrenvcheck:::has_renv_lock(temp_dir), info = 'has_renv_lock: empty dir')
  lock_file <- file.path(temp_dir, 'renv.lock')
  writeLines('{}', lock_file)
  expect_true(zzrenvcheck:::has_renv_lock(temp_dir), info = 'has_renv_lock: file present')
})
