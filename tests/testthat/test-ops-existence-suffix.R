# Tests for suffix-related existence ops:
#   op_no_var_with_suffix    (Q24, ADSL *FL presence)
#   op_var_by_suffix_not_numeric  (Q11, ADaM-58/59/60/716)

test_that("op_no_var_with_suffix fires when no variable carries the suffix", {
  adsl <- data.frame(USUBJID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  out  <- op_no_var_with_suffix(adsl, list(), suffix = "FL")
  expect_true(isTRUE(out[[1L]]))
})

test_that("op_no_var_with_suffix silent when any column matches", {
  adsl <- data.frame(USUBJID = "S1", SAFFL = "Y", stringsAsFactors = FALSE)
  out  <- op_no_var_with_suffix(adsl, list(), suffix = "FL")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_no_var_with_suffix is case-insensitive on name + suffix", {
  adsl <- data.frame(usubjid = "S1", saffl = "Y", stringsAsFactors = FALSE)
  out  <- op_no_var_with_suffix(adsl, list(), suffix = "fl")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_no_var_with_suffix returns a dataset-level mask", {
  adsl <- data.frame(USUBJID = c("S1","S2","S3"), stringsAsFactors = FALSE)
  out  <- op_no_var_with_suffix(adsl, list(), suffix = "FL")
  expect_equal(length(out), 3L)
  expect_true(isTRUE(out[[1L]]))
  expect_false(any(out[-1L]))
})

test_that("op_no_var_with_suffix passes through when suffix empty", {
  adsl <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  out  <- op_no_var_with_suffix(adsl, list(), suffix = "")
  expect_false(isTRUE(out[[1L]]))
})

# --- op_var_by_suffix_not_numeric -------------------------------------------

test_that("op_var_by_suffix_not_numeric fires when column is character", {
  df  <- data.frame(EXSTDT = c("2020-01-01", "2020-02-01"),
                    stringsAsFactors = FALSE)
  out <- herald:::op_var_by_suffix_not_numeric(df, list(), name = "EXSTDT")
  expect_true(all(out))
})

test_that("op_var_by_suffix_not_numeric passes when column is numeric", {
  df  <- data.frame(EXSTDT = c(18000, 18001))
  out <- herald:::op_var_by_suffix_not_numeric(df, list(), name = "EXSTDT")
  expect_true(all(!out))
})

test_that("op_var_by_suffix_not_numeric returns NA when column absent", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  out <- herald:::op_var_by_suffix_not_numeric(df, list(), name = "EXSTDT")
  expect_true(all(is.na(out)))
  expect_equal(length(out), 1L)
})

test_that("op_var_by_suffix_not_numeric passes when exclude_prefix matches", {
  df  <- data.frame(ELTM = c("T12:00", "T13:00"), stringsAsFactors = FALSE)
  out <- herald:::op_var_by_suffix_not_numeric(df, list(),
                                               name = "ELTM",
                                               exclude_prefix = "EL")
  expect_true(all(!out))
})

test_that("op_var_by_suffix_not_numeric fires when exclude_prefix does not match", {
  df  <- data.frame(VSTM = c("T12:00", "T13:00"), stringsAsFactors = FALSE)
  out <- herald:::op_var_by_suffix_not_numeric(df, list(),
                                               name = "VSTM",
                                               exclude_prefix = "EL")
  expect_true(all(out))
})

test_that("op_var_by_suffix_not_numeric empty exclude_prefix has no effect", {
  df  <- data.frame(ELTM = c("T12:00"), stringsAsFactors = FALSE)
  out <- herald:::op_var_by_suffix_not_numeric(df, list(),
                                               name = "ELTM",
                                               exclude_prefix = "")
  expect_true(all(out))
})
