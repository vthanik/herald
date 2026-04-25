mk_data <- function() {
  data.frame(
    USUBJID = c("S1", "S2", NA_character_, ""),
    AGE     = c(65L, NA_integer_, 42L, 30L),
    stringsAsFactors = FALSE
  )
}

test_that("exists returns TRUE/FALSE for whole dataset", {
  d <- mk_data()
  expect_equal(op_exists(d, NULL, "USUBJID"), rep(TRUE, 4L))
  expect_equal(op_exists(d, NULL, "NOPE"),    rep(FALSE, 4L))
})

test_that("not_exists is the inverse", {
  d <- mk_data()
  expect_equal(op_not_exists(d, NULL, "USUBJID"), rep(FALSE, 4L))
  expect_equal(op_not_exists(d, NULL, "NOPE"),    rep(TRUE, 4L))
})

test_that("non_empty: character NA and empty string both fail", {
  d <- mk_data()
  expect_equal(op_non_empty(d, NULL, "USUBJID"), c(TRUE, TRUE, FALSE, FALSE))
})

test_that("non_empty: integer NA fails; zero passes", {
  d <- mk_data()
  expect_equal(op_non_empty(d, NULL, "AGE"), c(TRUE, FALSE, TRUE, TRUE))
})

test_that("empty mirrors non_empty", {
  d <- mk_data()
  expect_equal(op_empty(d, NULL, "USUBJID"), c(FALSE, FALSE, TRUE, TRUE))
  expect_equal(op_empty(d, NULL, "AGE"),     c(FALSE, TRUE, FALSE, FALSE))
})

test_that("is_missing / is_present are synonyms", {
  d <- mk_data()
  expect_equal(op_is_missing(d, NULL, "USUBJID"), op_empty(d, NULL, "USUBJID"))
  expect_equal(op_is_present(d, NULL, "USUBJID"), op_non_empty(d, NULL, "USUBJID"))
})

test_that("missing column returns NA mask", {
  d <- mk_data()
  expect_equal(op_non_empty(d, NULL, "NONEXISTENT"), rep(NA, 4L))
  expect_equal(op_empty(d, NULL, "NONEXISTENT"),     rep(NA, 4L))
})

test_that("dataset-level not_exists collapses to a single fire when dataset missing", {
  ae <- data.frame(USUBJID = c("S1", "S2", "S3"), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae))  # EX is NOT in the submission
  # Without dataset-level detection, this would fire per row (3 TRUEs).
  expect_equal(op_not_exists(ae, ctx, "EX"), c(TRUE, FALSE, FALSE))
})

test_that("dataset-level not_exists does not fire when dataset is present", {
  ae <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  ex <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, EX = ex))
  expect_equal(op_not_exists(ae, ctx, "EX"), c(FALSE, FALSE))
})

test_that("dataset-level exists fires once when the referenced dataset is present", {
  ae <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  ex <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, EX = ex))
  expect_equal(op_exists(ae, ctx, "EX"), c(TRUE, FALSE))
})

test_that("column-level exists still works when name matches a column", {
  ae <- data.frame(EX = c(1, 2, 3), USUBJID = c("a","b","c"), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae))
  # "EX" IS a column here -- stay at column-level.
  expect_equal(op_exists(ae, ctx, "EX"), rep(TRUE, 3L))
  expect_equal(op_not_exists(ae, ctx, "EX"), rep(FALSE, 3L))
})

test_that("empty/non_empty treat trailing-whitespace-only strings as null (P21 rtrim convention)", {
  d <- data.frame(
    x = c("", "   ", "text", "text   ", "   leading", "0", "NA", "null", "n/a"),
    stringsAsFactors = FALSE
  )
  # Empty string and whitespace-only are null; text with leading or trailing
  # whitespace is populated (rtrim strips trailing, leading preserved);
  # "0", "NA", "null" are literal strings = populated.
  expect_equal(
    op_empty(d, NULL, "x"),
    c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)
  )
  expect_equal(
    op_non_empty(d, NULL, "x"),
    c(FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE)
  )
})

test_that("numeric zero is not null", {
  d <- data.frame(x = c(0, NA, 1, -1), stringsAsFactors = FALSE)
  expect_equal(op_empty(d, NULL, "x"), c(FALSE, TRUE, FALSE, FALSE))
  expect_equal(op_non_empty(d, NULL, "x"), c(TRUE, FALSE, TRUE, TRUE))
})
