# -----------------------------------------------------------------------------
# test-fast-ops-unique-relationship.R -- is_(not_)unique_relationship op
# -----------------------------------------------------------------------------
# Covers:
#   * Basic functional-dependency check (X -> Y should be 1:1)
#   * Right-trim null convention (P21 parity:
#     `DataEntryFactory.java:313-328`)
#   * "Considering only those rows on which both variables are populated":
#     NA rows in either column are excluded from the uniqueness count
#   * Single-row group: trivially unique
#   * All-rows-in-violating-group tagging (herald deviation from P21's
#     "fire only 2nd+ duplicate")

test_that("functional dependency X -> Y: same X, same Y -> no violation", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR"),
    PARAM   = c("Heart Rate", "Heart Rate", "Heart Rate"),
    stringsAsFactors = FALSE
  )
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  expect_equal(mask, c(FALSE, FALSE, FALSE))
})

test_that("X -> Y violation fires all rows in the violating group", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR", "BP"),
    PARAM   = c("Heart Rate", "Heart Rate", "Heart",       "Blood Pressure"),
    stringsAsFactors = FALSE
  )
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  # All three HR rows fire (violating group); the BP row does not.
  expect_equal(mask, c(TRUE, TRUE, TRUE, FALSE))
})

test_that("right-trim collapses 'Heart Rate' and 'Heart Rate ' to the same value", {
  d <- data.frame(
    PARAMCD = c("HR", "HR"),
    PARAM   = c("Heart Rate", "Heart Rate "),
    stringsAsFactors = FALSE
  )
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  # Both rows should collapse to same value -> NOT a violation.
  expect_equal(mask, c(FALSE, FALSE))
})

test_that("NA in either variable is excluded from the count", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR", "BP"),
    PARAM   = c("Heart Rate", NA, "", "Blood Pressure"),
    stringsAsFactors = FALSE
  )
  # Only the first HR row has both vars populated; others are excluded.
  # The HR group has one distinct PARAM -> no violation.
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  expect_equal(mask[1:4], c(FALSE, FALSE, FALSE, FALSE))
})

test_that("whitespace-only values collapse to NA (excluded)", {
  d <- data.frame(
    PARAMCD = c("HR", "HR"),
    PARAM   = c("Heart Rate", "   "),
    stringsAsFactors = FALSE
  )
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  expect_equal(mask, c(FALSE, FALSE))
})

test_that("single-row group is trivially unique", {
  d <- data.frame(PARAMCD = "HR", PARAM = "Heart Rate", stringsAsFactors = FALSE)
  expect_equal(op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM"),
               FALSE)
})

test_that("missing dependent column -> NA mask", {
  d <- data.frame(PARAMCD = c("HR", "HR"), stringsAsFactors = FALSE)
  mask <- op_is_not_unique_relationship(d, NULL, "PARAMCD", "PARAM")
  expect_equal(mask, rep(NA, 2L))
})
