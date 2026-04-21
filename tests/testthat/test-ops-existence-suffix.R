# Tests for op_no_var_with_suffix (plan Q24, ADSL *FL presence).

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
