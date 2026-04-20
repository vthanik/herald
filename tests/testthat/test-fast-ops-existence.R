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
