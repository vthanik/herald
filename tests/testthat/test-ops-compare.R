test_that("op_equal_to returns TRUE for matching single-value scalar", {
  d <- data.frame(x = c("A", "B", "A"), stringsAsFactors = FALSE)
  expect_equal(op_equal_to(d, NULL, "x", "A"), c(TRUE, FALSE, TRUE))
})

test_that("op_greater_than returns correct logical vector for scalar comparison", {
  d <- data.frame(x = c(1, 5, 3, 8), stringsAsFactors = FALSE)
  expect_equal(op_greater_than(d, NULL, "x", 4), c(FALSE, TRUE, FALSE, TRUE))
})

test_that("scalar compare ops return NA when value is a multi-element vector", {
  d <- data.frame(x = c(1, 2, 3), stringsAsFactors = FALSE)
  # Simulating a $-ref that resolved to multiple values -- scalar compare
  # can't express join-by-key; should advisory, not fire per row.
  expect_equal(op_equal_to(d, NULL, "x", c(1, 2, 3)), rep(NA, 3L))
  expect_equal(op_not_equal_to(d, NULL, "x", c(1, 2, 3)), rep(NA, 3L))
  expect_equal(op_greater_than(d, NULL, "x", c(1, 2)), rep(NA, 3L))
  # Scalar value still works normally.
  expect_equal(op_equal_to(d, NULL, "x", 2), c(FALSE, TRUE, FALSE))
})

mk_data <- function() {
  data.frame(
    IECAT   = c("INCLUSION", "EXCLUSION", "INCLUSION", "INCLUSION"),
    IEORRES = c("Y", "N", "Y", ""),
    AGE     = c(65, 72, 50, 30),
    AGEU    = c("YEARS", "YEARS", "YEARS", "YEARS"),
    stringsAsFactors = FALSE
  )
}

test_that("equal_to (literal)", {
  d <- mk_data()
  expect_equal(
    op_equal_to(d, NULL, "IECAT", "INCLUSION"),
    c(TRUE, FALSE, TRUE, TRUE)
  )
})

test_that("not_equal_to (literal)", {
  d <- mk_data()
  expect_equal(
    op_not_equal_to(d, NULL, "IECAT", "INCLUSION"),
    c(FALSE, TRUE, FALSE, FALSE)
  )
})

test_that("case-insensitive equality", {
  d <- mk_data()
  expect_equal(
    op_equal_to_ci(d, NULL, "IECAT", "inclusion"),
    c(TRUE, FALSE, TRUE, TRUE)
  )
})

test_that("ordinal comparisons on numeric column", {
  d <- mk_data()
  expect_equal(op_greater_than(d, NULL, "AGE", 60),              c(TRUE, TRUE, FALSE, FALSE))
  expect_equal(op_greater_than_or_equal_to(d, NULL, "AGE", 65),  c(TRUE, TRUE, FALSE, FALSE))
  expect_equal(op_less_than(d, NULL, "AGE", 60),                 c(FALSE, FALSE, TRUE, TRUE))
  expect_equal(op_less_than_or_equal_to(d, NULL, "AGE", 65),     c(TRUE, FALSE, TRUE, TRUE))
})

test_that("is_contained_by / is_not_contained_by", {
  d <- mk_data()
  allowed <- list("INCLUSION", "SCREENING")
  expect_equal(op_is_contained_by(d, NULL, "IECAT", allowed),       c(TRUE, FALSE, TRUE, TRUE))
  expect_equal(op_is_not_contained_by(d, NULL, "IECAT", allowed),   c(FALSE, TRUE, FALSE, FALSE))
})

test_that("case-insensitive set membership", {
  d <- mk_data()
  allowed <- list("inclusion")
  expect_equal(op_is_contained_by_ci(d, NULL, "IECAT", allowed),      c(TRUE, FALSE, TRUE, TRUE))
})

test_that("is_unique_set with composite key", {
  d <- data.frame(STUDYID = c("S1","S1","S1","S2"),
                  USUBJID = c("U1","U1","U2","U1"),
                  stringsAsFactors = FALSE)
  # Composite (STUDYID, USUBJID): rows 1+2 dup, others unique
  expect_equal(
    op_is_unique_set(d, NULL, c("STUDYID", "USUBJID")),
    c(FALSE, FALSE, TRUE, TRUE)
  )
})

test_that("is_not_unique_set is the inverse", {
  d <- data.frame(USUBJID = c("A","A","B"), stringsAsFactors = FALSE)
  expect_equal(op_is_not_unique_set(d, NULL, "USUBJID"), c(TRUE, TRUE, FALSE))
})
