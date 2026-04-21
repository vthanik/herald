# -----------------------------------------------------------------------------
# test-fast-ops-set.R -- is_contained_by / is_not_contained_by (P21-parity)
# -----------------------------------------------------------------------------

test_that("is_contained_by basic membership", {
  d <- data.frame(x = c("A", "B", "C"), stringsAsFactors = FALSE)
  expect_equal(op_is_contained_by(d, NULL, "x", c("A", "B")),
               c(TRUE, TRUE, FALSE))
})

test_that("is_contained_by right-trims the value (P21 rtrim parity)", {
  d <- data.frame(x = c("S1-001", "S1-001 ", "S1-002"),
                  stringsAsFactors = FALSE)
  expect_equal(op_is_contained_by(d, NULL, "x", c("S1-001")),
               c(TRUE, TRUE, FALSE))
})

test_that("is_contained_by returns NA when the row's value is null/empty", {
  d <- data.frame(x = c("A", "", "   ", NA_character_), stringsAsFactors = FALSE)
  m <- op_is_contained_by(d, NULL, "x", c("A", "B"))
  expect_equal(m, c(TRUE, NA, NA, NA))
})

test_that("is_not_contained_by is the complement, preserving NA", {
  d <- data.frame(x = c("A", "C", "", NA_character_), stringsAsFactors = FALSE)
  m <- op_is_not_contained_by(d, NULL, "x", c("A", "B"))
  expect_equal(m, c(FALSE, TRUE, NA, NA))
})

test_that("missing column returns all-NA mask", {
  d <- data.frame(y = "A", stringsAsFactors = FALSE)
  expect_equal(op_is_contained_by(d, NULL, "x", c("A")), rep(NA, 1L))
})
