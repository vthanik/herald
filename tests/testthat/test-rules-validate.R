# Tests for R/rules-validate.R internals.

test_that(".dup_subjects_scan() flags duplicate USUBJIDs per dataset", {
  dm <- data.frame(USUBJID = c("S1", "S2", "S1"), stringsAsFactors = FALSE)
  ae <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  cache <- .dup_subjects_scan(list(DM = dm, AE = ae))

  expect_equal(cache$DM, "S1")
  expect_equal(cache$AE, character(0))
})

test_that(".dup_subjects_scan() returns NA for datasets without USUBJID", {
  cache <- .dup_subjects_scan(list(TA = data.frame(ARM = "A")))
  expect_true(is.na(cache$TA))
})

test_that(".dup_subjects_scan() is case-insensitive on column name", {
  dm <- data.frame(usubjid = c("S1", "S1"), stringsAsFactors = FALSE)
  cache <- .dup_subjects_scan(list(DM = dm))
  expect_equal(cache$DM, "S1")
})

test_that(".dup_subjects_scan() ignores NA and empty USUBJID values", {
  dm <- data.frame(
    USUBJID = c("S1", NA, "", "S1"),
    stringsAsFactors = FALSE
  )
  cache <- .dup_subjects_scan(list(DM = dm))
  expect_equal(cache$DM, "S1")
})

test_that(".dup_subjects_scan() handles non-data-frame entries", {
  cache <- .dup_subjects_scan(list(X = list(a = 1)))
  expect_true(is.na(cache$X))
})

test_that("validate() populates ctx$dup_subjects via pre-scan (end-to-end)", {
  # Minimal smoke: validate a dataset with a duplicate USUBJID. We cannot
  # read ctx directly from validate()'s return, but we can verify the
  # run completes and populates a herald_result without error.
  dm <- data.frame(
    USUBJID  = c("S1", "S1"),
    stringsAsFactors = FALSE
  )
  attr(dm, "label") <- "Demographics"
  # Passing a dataset named DM through validate() exercises the scan path.
  result <- validate(files = list(DM = dm), quiet = TRUE)
  expect_s3_class(result, "herald_result")
})
