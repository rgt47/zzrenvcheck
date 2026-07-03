# Tests for Package Extraction Functions

extract_packages_from_file_lines <- function(lines, skip_comments = TRUE) {
  if (skip_comments) {
    is_roxygen <- grepl("^\\s*#'", lines)
    is_comment <- grepl('^\\s*#', lines) & !is_roxygen
    lines[is_comment] <- ''
  }
  packages <- character(0)
  packages <- c(packages, zzrenvcheck:::extract_library_calls(lines))
  packages <- c(packages, zzrenvcheck:::extract_require_calls(lines))
  packages <- c(packages, zzrenvcheck:::extract_namespace_calls(lines))
  packages <- c(packages, zzrenvcheck:::extract_roxygen_imports(lines))
  packages
}

# extract_library_calls finds library() calls
local({
  lines <- c(
    'library(dplyr)',
    "library('ggplot2')",
    'library("tidyr")'
  )
  pkgs <- zzrenvcheck:::extract_library_calls(lines)
  expect_true('dplyr' %in% pkgs, info = 'library: dplyr')
  expect_true('ggplot2' %in% pkgs, info = 'library: ggplot2')
  expect_true('tidyr' %in% pkgs, info = 'library: tidyr')
})

# extract_require_calls finds require() calls
local({
  lines <- c(
    'require(dplyr)',
    "require('ggplot2')",
    'require("tidyr")'
  )
  pkgs <- zzrenvcheck:::extract_require_calls(lines)
  expect_true('dplyr' %in% pkgs, info = 'require: dplyr')
  expect_true('ggplot2' %in% pkgs, info = 'require: ggplot2')
  expect_true('tidyr' %in% pkgs, info = 'require: tidyr')
})

# extract_namespace_calls finds pkg:: calls
local({
  lines <- c(
    'dplyr::filter(data, x > 0)',
    'result <- ggplot2::ggplot()',
    'tidyr::pivot_longer(df)'
  )
  pkgs <- zzrenvcheck:::extract_namespace_calls(lines)
  expect_true('dplyr' %in% pkgs, info = 'namespace: dplyr')
  expect_true('ggplot2' %in% pkgs, info = 'namespace: ggplot2')
  expect_true('tidyr' %in% pkgs, info = 'namespace: tidyr')
})

# extract_roxygen_imports finds @importFrom
local({
  lines <- c(
    "#' @importFrom dplyr filter",
    "#' @importFrom ggplot2 ggplot aes"
  )
  pkgs <- zzrenvcheck:::extract_roxygen_imports(lines)
  expect_true('dplyr' %in% pkgs, info = '@importFrom: dplyr')
  expect_true('ggplot2' %in% pkgs, info = '@importFrom: ggplot2')
})

# extract_roxygen_imports finds @import
local({
  lines <- c(
    "#' @import dplyr",
    "#' @import ggplot2"
  )
  pkgs <- zzrenvcheck:::extract_roxygen_imports(lines)
  expect_true('dplyr' %in% pkgs, info = '@import: dplyr')
  expect_true('ggplot2' %in% pkgs, info = '@import: ggplot2')
})

# find_r_files skips renv/ as a segment, not an ancestor substring
local({
  # Ancestor directory name contains 'renv' but is not a renv/ dir.
  root <- file.path(tempfile(), 'zzrenvcheck_proj')
  dir.create(file.path(root, 'R'), recursive = TRUE)
  dir.create(file.path(root, 'renv'), recursive = TRUE)
  on.exit(unlink(dirname(root), recursive = TRUE), add = TRUE)
  writeLines('library(dplyr)', file.path(root, 'R', 'a.R'))
  writeLines('library(skipme)', file.path(root, 'renv', 'activate.R'))
  files <- zzrenvcheck:::find_r_files(c('R', 'renv'), root)
  expect_true(any(grepl('a.R', files, fixed = TRUE)),
              info = 'file under renv-named ancestor is kept')
  expect_false(any(grepl('activate.R', files, fixed = TRUE)),
               info = 'file inside renv/ segment is skipped')
})

# extract ignores commented code
local({
  lines <- c(
    'library(dplyr)',
    '# library(ggplot2)',
    '  # library(tidyr)'
  )
  pkgs_with <- extract_packages_from_file_lines(lines, skip_comments = FALSE)
  pkgs_without <- extract_packages_from_file_lines(lines, skip_comments = TRUE)
  expect_true('dplyr' %in% pkgs_without, info = 'comments: dplyr kept')
  expect_false('ggplot2' %in% pkgs_without, info = 'comments: ggplot2 dropped')
  expect_false('tidyr' %in% pkgs_without, info = 'comments: tidyr dropped')
})

# Rmd: package refs in markdown/LaTeX prose are ignored; only code chunks count
local({
  d <- tempfile('rmd'); dir.create(file.path(d, 'analysis'), recursive = TRUE)
  writeLines(c(
    '---', 'title: t', '---',
    'Compare to \\texttt{Exact::exact.test} and install via',
    '\\texttt{remotes::install_github("x/y")}.',
    'Inline `r glue::glue("hi")` counts as code.',
    '```{r}', 'library(dplyr)', 'kableExtra::kbl(1)', '```'
  ), file.path(d, 'analysis', 'report.Rmd'))
  pkgs <- zzrenvcheck:::clean_package_names(
    extract_code_packages(dirs = 'analysis', path = d))
  expect_true('dplyr' %in% pkgs, info = 'chunk library() detected')
  expect_true('kableExtra' %in% pkgs, info = 'chunk :: detected')
  expect_true('glue' %in% pkgs, info = 'inline `r ...` detected')
  expect_false('Exact' %in% pkgs, info = 'LaTeX prose :: ignored (Exact)')
  expect_false('remotes' %in% pkgs, info = 'LaTeX prose :: ignored (remotes)')
  unlink(d, recursive = TRUE)
})

# .renvignore excludes listed sources from the scan
local({
  d <- tempfile('ign'); dir.create(file.path(d, 'analysis'), recursive = TRUE)
  writeLines(c('```{r}', 'library(dplyr)', '```'),
             file.path(d, 'analysis', 'report.Rmd'))
  writeLines(c('```{r}', 'library(pacman)', '```'),
             file.path(d, 'analysis', 'paper.Rmd'))
  before <- zzrenvcheck:::clean_package_names(
    extract_code_packages(dirs = 'analysis', path = d))
  expect_true('pacman' %in% before, info = 'paper.Rmd scanned without ignore')
  writeLines('paper.Rmd', file.path(d, '.renvignore'))
  after <- zzrenvcheck:::clean_package_names(
    extract_code_packages(dirs = 'analysis', path = d))
  expect_false('pacman' %in% after, info = '.renvignore drops paper.Rmd')
  expect_true('dplyr' %in% after, info = '.renvignore keeps report.Rmd')
  unlink(d, recursive = TRUE)
})
