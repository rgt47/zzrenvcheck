# Role-aware placement and structural (LinkingTo/Depends) handling

# parse_description_structural returns LinkingTo + Depends, excluding base R
local({
  d <- tempfile("struct"); dir.create(d)
  writeLines(c("Package: demo", "Version: 0.0.1",
               "Depends: R (>= 4.0), methodsA",
               "LinkingTo: Rcpp", "Imports: Rcpp"),
             file.path(d, "DESCRIPTION"))
  s <- zzrenvcheck:::parse_description_structural(d)
  expect_true("Rcpp" %in% s, info = "LinkingTo package detected")
  expect_true("methodsA" %in% s, info = "Depends package detected")
  expect_false("R" %in% s, info = "base R excluded")
  unlink(d, recursive = TRUE)
})

# auto-fix places R/ deps in Imports and analysis/ deps in Suggests
local({
  d <- tempfile("place"); dir.create(file.path(d, "R"), recursive = TRUE)
  dir.create(file.path(d, "analysis"))
  writeLines(c("Package: demo", "Version: 0.0.1"), file.path(d, "DESCRIPTION"))
  writeLines("dplyr::filter(x)", file.path(d, "R", "f.R"))
  writeLines(c("```{r}", "library(kableExtra)", "```"),
             file.path(d, "analysis", "report.Rmd"))
  zzrenvcheck:::handle_auto_fix_description(c("dplyr", "kableExtra"), path = d)
  deps <- desc::desc(file.path(d, "DESCRIPTION"))$get_deps()
  imp <- deps$package[deps$type == "Imports"]
  sug <- deps$package[deps$type == "Suggests"]
  expect_true("dplyr" %in% imp, info = "R/ dep -> Imports")
  expect_true("kableExtra" %in% sug, info = "analysis/ dep -> Suggests")
  expect_false("kableExtra" %in% imp, info = "analysis/ dep not in Imports")
  unlink(d, recursive = TRUE)
})

# a LinkingTo package is not reported as unused
local({
  d <- tempfile("unused"); dir.create(file.path(d, "R"), recursive = TRUE)
  writeLines(c("Package: demo", "Version: 0.0.1",
               "LinkingTo: Rcpp", "Imports: Rcpp"),
             file.path(d, "DESCRIPTION"))
  writeLines("dplyr::filter(x)", file.path(d, "R", "f.R"))
  res <- check_packages(auto_fix = FALSE, strict = FALSE, versions = FALSE,
                        path = d, verbose = FALSE)
  expect_false("Rcpp" %in% res$unused_in_description,
               info = "LinkingTo Rcpp not flagged unused")
  unlink(d, recursive = TRUE)
})
