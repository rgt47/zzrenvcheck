# check_packages(cleanup = TRUE) must honor error_on_fail and forward the
# caller's image settings to the sync (reconciliation item F3)

make_cleanup_project <- function(desc_imports) {
  d <- tempfile('cleanup')
  dir.create(file.path(d, 'R'), recursive = TRUE)
  writeLines(c('Package: smoke', 'Version: 0.1.0', 'Imports:',
               paste0('    ', desc_imports, collapse = ',\n')),
             file.path(d, 'DESCRIPTION'))
  writeLines(c('jsonlite::toJSON(1)', 'cli::cli_text("x")'),
             file.path(d, 'R', 'a.R'))
  writeLines(paste0('{"R":{"Version":"4.4.0"},"Packages":{',
                    '"jsonlite":{"Package":"jsonlite","Version":"1.0"},',
                    '"cli":{"Package":"cli","Version":"1.0"}}}'),
             file.path(d, 'renv.lock'))
  d
}

run_cleanup <- function(d, ...) {
  tryCatch({
    suppressMessages(check_packages(path = d, strict = FALSE,
                                    cleanup = TRUE, ...))
    'returned'
  }, zzrenvcheck_validation_failure = function(e) 'gate error')
}

# A version conflict survives the sync, so the gate must fire
local({
  d <- make_cleanup_project(c('jsonlite (>= 99.0)', 'cli'))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_equal(run_cleanup(d, error_on_fail = TRUE, versions = TRUE),
               'gate error',
               info = 'F3: cleanup = TRUE raises when issues remain')
})

local({
  d <- make_cleanup_project(c('jsonlite (>= 99.0)', 'cli'))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_equal(run_cleanup(d, error_on_fail = TRUE, versions = FALSE),
               'returned',
               info = 'F3: cleanup gate re-check honors versions = FALSE')
})

local({
  d <- make_cleanup_project(c('jsonlite (>= 99.0)', 'cli'))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_equal(run_cleanup(d, error_on_fail = FALSE, versions = TRUE),
               'returned',
               info = 'F3: cleanup does not raise when error_on_fail = FALSE')
})

# skip_image_pkgs and image must reach the sync and the re-check
local({
  d <- make_cleanup_project(c('jsonlite', 'cli'))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  ns <- asNamespace('zzrenvcheck')
  original <- get('get_image_packages', envir = ns)
  seen_images <- character(0)
  unlockBinding('get_image_packages', ns)
  assign('get_image_packages', function(image, ...) {
    seen_images <<- c(seen_images, image)
    'cli'
  }, envir = ns)
  on.exit({
    assign('get_image_packages', original, envir = ns)
    lockBinding('get_image_packages', ns)
  }, add = TRUE)
  res <- suppressMessages(check_packages(
    path = d, strict = FALSE, cleanup = TRUE, error_on_fail = TRUE,
    versions = FALSE, skip_image_pkgs = TRUE, image = 'myimage'
  ))
  expect_equal(res$removed_from_description, 'cli',
               info = 'F3: cleanup forwards skip_image_pkgs to the sync')
  expect_equal(seen_images, c('myimage', 'myimage'),
               info = 'F3: cleanup sync and re-check query the same image')
})
