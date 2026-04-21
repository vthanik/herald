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

test_that(".is_submission_scope() detects the submission flag", {
  expect_false(.is_submission_scope(list(scope = list(classes = "ALL"))))
  expect_true(.is_submission_scope(list(scope = list(submission = TRUE))))
  expect_true(.is_submission_scope(list(scope = list(submission = "true"))))
  expect_false(.is_submission_scope(list(scope = list(submission = FALSE))))
  expect_false(.is_submission_scope(list(scope = NULL)))
})

test_that("validate() routes submission-level rules to a single finding", {
  # ADaM-1 declares scope.submission: true and check not_exists(ADSL).
  # When ADSL is absent, exactly one finding at dataset='<submission>'.
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(files = list(DM = dm), rules = "1", quiet = TRUE)
  expect_equal(nrow(result$findings), 1L)
  expect_equal(result$findings$dataset, "<submission>")
  expect_equal(result$findings$status,  "fired")
  expect_true(is.na(result$findings$row))
})

test_that("submission-level rule is silent when the target dataset exists", {
  adsl <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  dm   <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(files = list(ADSL = adsl, DM = dm),
                     rules = "1", quiet = TRUE)
  expect_equal(nrow(result$findings), 0L)
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
