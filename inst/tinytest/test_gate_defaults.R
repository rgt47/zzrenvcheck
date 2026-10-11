# Gate defaults (error_on_fail) and installed-version auto-fix

make_project <- function(desc_lines, code = NULL, lock_packages = '{}') {
  d <- tempfile('gate')
  dir.create(file.path(d, 'R'), recursive = TRUE)
  writeLines(desc_lines, file.path(d, 'DESCRIPTION'))
  if (!is.null(code)) writeLines(code, file.path(d, 'R', 'a.R'))
  writeLines(
    paste0('{"R":{"Version":"4.4.0"},"Packages":', lock_packages, '}'),
    file.path(d, 'renv.lock')
  )
  d
}

failing_project <- function() {
  make_project(c('Package: smoke', 'Version: 0.1.0'),
               code = 'jsonlite::toJSON(1)')
}

# The default is the expression !interactive(), not a constant
local({
  default <- formals(check_packages)$error_on_fail
  expect_identical(default, quote(!interactive()),
                   info = 'default is !interactive()')
  expect_false(eval(default, list(interactive = function() TRUE)),
               info = 'default is FALSE in an interactive session')
  expect_true(eval(default, list(interactive = function() FALSE)),
              info = 'default is TRUE under Rscript or CI')
})

# error_on_fail = TRUE stops on a failed check
local({
  d <- failing_project()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_error(
    suppressMessages(check_packages(path = d, strict = FALSE,
                                    versions = FALSE, error_on_fail = TRUE)),
    class = 'zzrenvcheck_validation_failure',
    info = 'explicit error_on_fail = TRUE errors on failure'
  )
})

# error_on_fail = FALSE reports only
local({
  d <- failing_project()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  r <- suppressMessages(check_packages(path = d, strict = FALSE,
                                       versions = FALSE,
                                       error_on_fail = FALSE))
  expect_equal(r$status, 'fail', info = 'report-only returns fail status')
})

# Under a non-interactive run, the default errors without being asked to
if (!interactive()) {
  local({
    d <- failing_project()
    on.exit(unlink(d, recursive = TRUE), add = TRUE)
    expect_error(
      suppressMessages(check_packages(path = d, strict = FALSE,
                                      versions = FALSE)),
      class = 'zzrenvcheck_validation_failure',
      info = 'default errors on failure when not interactive'
    )
  })
}

# Auto-fix records the installed version and source, in the same run as the
# DESCRIPTION fix, and the gate passes once the fix resolves every issue
local({
  d <- failing_project()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  r <- suppressMessages(check_packages(
    path = d, strict = FALSE, versions = FALSE, auto_fix = TRUE,
    validate_sources = FALSE, error_on_fail = TRUE
  ))
  expect_equal(r$status_after_fix, 'pass',
               info = 'no error when auto-fix resolves all issues')
  lock <- jsonlite::fromJSON(file.path(d, 'renv.lock'),
                             simplifyVector = FALSE)
  entry <- lock$Packages$jsonlite
  expect_false(is.null(entry), info = 'added to renv.lock in one run')
  expect_equal(entry$Version,
               as.character(utils::packageVersion('jsonlite')),
               info = 'lock records the installed version')
  installed_repo <- utils::packageDescription('jsonlite')$Repository
  if (!is.null(installed_repo)) {
    expect_equal(entry$Repository, installed_repo,
                 info = 'lock records the installed Repository field')
  }
})

# Auto-fix cannot repair a version conflict, so the gate still fails
local({
  d <- make_project(
    c('Package: smoke', 'Version: 0.1.0',
      'Imports:', '    jsonlite (>= 999.0.0)'),
    code = 'jsonlite::toJSON(1)',
    lock_packages = '{"jsonlite":{"Package":"jsonlite","Version":"1.0"}}'
  )
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_error(
    suppressMessages(check_packages(
      path = d, strict = FALSE, auto_fix = TRUE, validate_sources = FALSE,
      error_on_fail = TRUE
    )),
    class = 'zzrenvcheck_validation_failure',
    info = 'issues remaining after auto-fix still fail the gate'
  )
})

# installed_lock_entry reads GitHub remote fields from the installed copy
local({
  lib <- tempfile('lib')
  dir.create(file.path(lib, 'fakegh'), recursive = TRUE)
  on.exit(unlink(lib, recursive = TRUE), add = TRUE)
  writeLines(c(
    'Package: fakegh', 'Version: 0.2.1', 'RemoteType: github',
    'RemoteUsername: someone', 'RemoteRepo: fakegh', 'RemoteRef: main',
    'RemoteSha: abc123'
  ), file.path(lib, 'fakegh', 'DESCRIPTION'))
  e <- zzrenvcheck:::installed_lock_entry('fakegh', lib.loc = lib)
  expect_equal(e$Version, '0.2.1', info = 'GitHub install: version')
  expect_equal(e$Source, 'GitHub', info = 'GitHub install: source')
  expect_equal(e$RemoteSha, 'abc123', info = 'GitHub install: sha kept')
  expect_null(zzrenvcheck:::installed_lock_entry('notapkgzz', lib.loc = lib),
              info = 'NULL when not installed')
})

# Not installed: fall back to CRAN, with a warning message
local({
  d <- make_project(c('Package: smoke', 'Version: 0.1.0'))
  lib <- tempfile('emptylib')
  dir.create(lib)
  on.exit(unlink(c(d, lib), recursive = TRUE), add = TRUE)
  ns <- asNamespace('zzrenvcheck')
  original <- get('fetch_cran_info', envir = ns)
  unlockBinding('fetch_cran_info', ns)
  assign('fetch_cran_info', function(package) list(Version = '9.9.9'),
         envir = ns)
  on.exit({
    assign('fetch_cran_info', original, envir = ns)
    lockBinding('fetch_cran_info', ns)
  }, add = TRUE)
  msgs <- character(0)
  ok <- withCallingHandlers(
    zzrenvcheck:::add_to_renv_lock('notinstalledzz', path = d,
                                   lib.loc = lib),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart('muffleMessage')
    }
  )
  expect_true(ok, info = 'CRAN fallback succeeds')
  lock <- jsonlite::fromJSON(file.path(d, 'renv.lock'),
                             simplifyVector = FALSE)
  expect_equal(lock$Packages$notinstalledzz$Version, '9.9.9',
               info = 'CRAN version recorded when not installed')
  expect_true(any(grepl('not installed', msgs)),
              info = 'fallback is announced')
})
