# --- regressions -------------------------------------------------
#
# The package exists to catch a dependency that is used but not
# declared, so a missed usage is its central failure mode. Three
# idioms were missed and three non-usages were counted.

sandbox <- file.path(tempdir(), paste0("zzrenv-idioms-",
                                       as.integer(Sys.time())))
unlink(sandbox, recursive = TRUE)
dir.create(file.path(sandbox, "R"), recursive = TRUE)
writeLines(c(
  'library(alpha)',
  'require(bravo)',
  'requireNamespace("charlie")',
  'requireNamespace("delta", quietly = TRUE)',
  'loadNamespace("echo")',
  'foxtrot::fun()',
  'golf:::internal_fun()',
  'x <- 1  # trailing comment mentions hotel::thing',
  'msg <- "text mentioning india::thing"',
  "msg2 <- 'juliet::thing in single quotes'",
  "#' @importFrom kilo some_fn",
  'lima  ::  spaced()',
  'library("oscar")',
  'suppressMessages(library(papa))'
), file.path(sandbox, "R", "probe.R"))

found <- sort(unique(suppressMessages(
  extract_code_packages(dirs = "R", path = sandbox))))

# requireNamespace() and loadNamespace() are the standard idioms for an
# optional dependency, the form CRAN expects for anything in Suggests.
# Neither matched the require( pattern nor the :: pattern, so a package
# used only that way was omitted from the dependency set entirely.
for (p in c("charlie", "delta", "echo")) {
  expect_true(p %in% found,
    info = paste(p, "is found through requireNamespace/loadNamespace"))
}
# R allows space around ::; the pattern required none.
expect_true("lima" %in% found,
  info = "a namespaced call with spaces around :: is found")
# The idioms that already worked must keep working.
for (p in c("alpha", "bravo", "foxtrot", "golf", "kilo", "oscar",
            "papa")) {
  expect_true(p %in% found,
    info = paste(p, "is still found"))
}

# A package named in a trailing comment or inside a string literal is
# not a dependency. Counting it produced a spurious "undeclared
# package" report, which auto-fix would then act on.
for (p in c("hotel", "india", "juliet")) {
  expect_false(p %in% found,
    info = paste(p, "is not counted from a comment or string"))
}

unlink(sandbox, recursive = TRUE)

# The masking helper itself. Assert the properties rather than exact
# padding, so the test says what matters instead of counting spaces.
mask <- zzrenvcheck:::mask_strings_and_comments
one <- 'x <- "a::b"  # c::d'
expect_false(grepl("::", mask(one)),
  info = "no namespace operator survives inside a string or comment")
expect_equal(nchar(mask(one)), nchar(one),
  info = "masking preserves line length")

two <- 'pkg::fn("arg")'
expect_true(grepl("pkg::fn", mask(two), fixed = TRUE),
  info = "code outside strings is preserved")
expect_false(grepl("arg", mask(two), fixed = TRUE),
  info = "the string argument is blanked")

three <- 'x <- "has # inside"'
expect_equal(nchar(mask(three)), nchar(three),
  info = "a hash inside a string does not truncate the line")
expect_true(endsWith(mask(three), '"'),
  info = "a hash inside a string does not start a comment")
