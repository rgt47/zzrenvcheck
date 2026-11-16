# The post-fix re-check must use the caller's compendium and image settings

make_recheck_project <- function() {
  d <- tempfile('recheck')
  dir.create(file.path(d, 'R'), recursive = TRUE)
  dir.create(file.path(d, 'scripts'))
  writeLines(c('Package: smoke', 'Version: 0.1.0', 'Imports:',
               '    jsonlite'), file.path(d, 'DESCRIPTION'))
  writeLines('jsonlite::toJSON(1)', file.path(d, 'R', 'a.R'))
  writeLines('{"R":{"Version":"4.4.0"},"Packages":{}}',
             file.path(d, 'renv.lock'))
  d
}

run_fix <- function(d, ...) {
  tryCatch(
    suppressMessages(check_packages(
      path = d, strict = FALSE, versions = FALSE, auto_fix = TRUE,
      validate_sources = FALSE, error_on_fail = TRUE, ...
    ))$status_after_fix,
    zzrenvcheck_validation_failure = function(e) 'gate error'
  )
}

# compendium = TRUE without analysis/: a scripts/-only package is exempt from
# DESCRIPTION, and the re-check must not revert to 'auto' (package mode)
local({
  d <- make_recheck_project()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  writeLines('cli::cli_text("x")', file.path(d, 'scripts', 's.R'))
  writeLines(paste0('{"R":{"Version":"4.4.0"},"Packages":{"cli":',
                    '{"Package":"cli","Version":"1.0"}}}'),
             file.path(d, 'renv.lock'))
  expect_equal(run_fix(d, compendium = TRUE), 'pass',
               info = 'post-fix re-check keeps compendium = TRUE')
})

# skip_image_pkgs = TRUE: an image package is exempt, and the re-check must
# apply the same exemption with the same image name
local({
  d <- make_recheck_project()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  writeLines('cli::cli_text("x")', file.path(d, 'R', 'b.R'))
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
  expect_equal(run_fix(d, skip_image_pkgs = TRUE, image = 'myimage'),
               'pass',
               info = 'post-fix re-check keeps skip_image_pkgs = TRUE')
  expect_equal(seen_images, c('myimage', 'myimage'),
               info = 'post-fix re-check queries the same image')
})
