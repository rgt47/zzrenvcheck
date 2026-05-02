# Tests for Package Name Cleaning and Validation

# clean_package_names removes base packages
local({
  packages <- c('dplyr', 'base', 'utils', 'ggplot2', 'stats')
  cleaned <- clean_package_names(packages)
  expect_true('dplyr' %in% cleaned, info = 'removes base: dplyr kept')
  expect_true('ggplot2' %in% cleaned, info = 'removes base: ggplot2 kept')
  expect_false('base' %in% cleaned, info = 'removes base: base dropped')
  expect_false('utils' %in% cleaned, info = 'removes base: utils dropped')
  expect_false('stats' %in% cleaned, info = 'removes base: stats dropped')
})

# clean_package_names removes short names
local({
  packages <- c('dplyr', 'my', 'an', 'if', 'ggplot2')
  cleaned <- clean_package_names(packages)
  expect_true('dplyr' %in% cleaned, info = 'short names: dplyr kept')
  expect_true('ggplot2' %in% cleaned, info = 'short names: ggplot2 kept')
  expect_false('my' %in% cleaned, info = 'short names: my dropped')
  expect_false('an' %in% cleaned, info = 'short names: an dropped')
  expect_false('if' %in% cleaned, info = 'short names: if dropped')
})

# clean_package_names validates format
local({
  packages <- c('dplyr', '.invalid', 'invalid.', '123pkg', 'valid.pkg')
  cleaned <- clean_package_names(packages)
  expect_true('dplyr' %in% cleaned, info = 'format: dplyr kept')
  expect_true('valid.pkg' %in% cleaned, info = 'format: valid.pkg kept')
  expect_false('.invalid' %in% cleaned, info = 'format: .invalid dropped')
  expect_false('invalid.' %in% cleaned, info = 'format: invalid. dropped')
  expect_false('123pkg' %in% cleaned, info = 'format: 123pkg dropped')
})

# clean_package_names removes placeholder names
local({
  packages <- c('dplyr', 'package', 'myproject', 'foo', 'bar')
  cleaned <- clean_package_names(packages)
  expect_true('dplyr' %in% cleaned, info = 'placeholders: dplyr kept')
  expect_false('package' %in% cleaned, info = 'placeholders: package dropped')
  expect_false('myproject' %in% cleaned, info = 'placeholders: myproject dropped')
  expect_false('foo' %in% cleaned, info = 'placeholders: foo dropped')
  expect_false('bar' %in% cleaned, info = 'placeholders: bar dropped')
})

# clean_package_names removes generic words
local({
  packages <- c('dplyr', 'my', 'your', 'file', 'path', 'name')
  cleaned <- clean_package_names(packages)
  expect_true('dplyr' %in% cleaned, info = 'generic words: dplyr kept')
  expect_false('my' %in% cleaned, info = 'generic words: my dropped')
  expect_false('your' %in% cleaned, info = 'generic words: your dropped')
  expect_false('file' %in% cleaned, info = 'generic words: file dropped')
  expect_false('path' %in% cleaned, info = 'generic words: path dropped')
  expect_false('name' %in% cleaned, info = 'generic words: name dropped')
})

# clean_package_names deduplicates
local({
  packages <- c('dplyr', 'dplyr', 'ggplot2', 'dplyr')
  cleaned <- clean_package_names(packages)
  expect_equal(sum(cleaned == 'dplyr'), 1, info = 'dedupe: one dplyr')
  expect_equal(length(cleaned), 2, info = 'dedupe: length 2')
})

# clean_package_names sorts alphabetically
local({
  packages <- c('zzz', 'aaa', 'mmm')
  cleaned <- clean_package_names(packages)
  expect_equal(cleaned, c('aaa', 'mmm', 'zzz'), info = 'sorted alphabetically')
})

# is_valid_package_name works correctly
expect_true(zzrenvcheck:::is_valid_package_name('dplyr'), info = 'valid: dplyr')
expect_true(zzrenvcheck:::is_valid_package_name('ggplot2'), info = 'valid: ggplot2')
expect_true(zzrenvcheck:::is_valid_package_name('data.table'), info = 'valid: data.table')
expect_false(zzrenvcheck:::is_valid_package_name('.invalid'), info = 'invalid: .invalid')
expect_false(zzrenvcheck:::is_valid_package_name('invalid.'), info = 'invalid: invalid.')
expect_false(zzrenvcheck:::is_valid_package_name('123invalid'), info = 'invalid: 123invalid')
expect_false(zzrenvcheck:::is_valid_package_name('invalid-name'), info = 'invalid: invalid-name')

# is_generic_word identifies common words
expect_true(zzrenvcheck:::is_generic_word('my'), info = 'generic: my')
expect_true(zzrenvcheck:::is_generic_word('your'), info = 'generic: your')
expect_true(zzrenvcheck:::is_generic_word('file'), info = 'generic: file')
expect_true(zzrenvcheck:::is_generic_word('path'), info = 'generic: path')
expect_false(zzrenvcheck:::is_generic_word('dplyr'), info = 'not generic: dplyr')
expect_false(zzrenvcheck:::is_generic_word('ggplot2'), info = 'not generic: ggplot2')
