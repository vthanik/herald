# -----------------------------------------------------------------------------
# test-ops-cross-next-row.R -- op_next_row_not_equal (Q29 / CG0207)
# -----------------------------------------------------------------------------

.mk_ctx_empty <- function() {
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list()
  ctx
}

ctx_empty <- .mk_ctx_empty()

# =============================================================================
# op_next_row_not_equal
# =============================================================================

test_that("next_row_not_equal fires on row where name != next row prev_name", {
  # SE-like dataset: 3 elements per subject.
  # SEENDTC of row 1 should equal SESTDTC of row 2 (no gaps).
  # Row 2 has a gap: SEENDTC="2024-01-05" but next SESTDTC="2024-01-07".
  d <- data.frame(
    USUBJID  = c("S1", "S1", "S1"),
    TAETORD  = c(1L,   2L,   3L),
    SESTDTC  = c("2024-01-01", "2024-01-03", "2024-01-07"),
    SEENDTC  = c("2024-01-03", "2024-01-05", "2024-01-10"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD",
                 group_by = list("USUBJID"))
  )
  # Row 1: SEENDTC="2024-01-03" == SESTDTC of row 2 "2024-01-03" -> pass
  # Row 2: SEENDTC="2024-01-05" != SESTDTC of row 3 "2024-01-07" -> fire
  # Row 3: last row -> no next element -> pass
  expect_equal(out, c(FALSE, TRUE, FALSE))
})

test_that("next_row_not_equal passes when all adjacent pairs match", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    TAETORD = c(1L, 2L, 3L),
    SESTDTC = c("2024-01-01", "2024-01-04", "2024-01-07"),
    SEENDTC = c("2024-01-04", "2024-01-07", "2024-01-10"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD",
                 group_by = list("USUBJID"))
  )
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

test_that("next_row_not_equal partitions by group_by independently", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S2", "S2"),
    TAETORD = c(1L,   2L,   1L,   2L),
    SESTDTC = c("2024-01-01", "2024-01-05", "2024-02-01", "2024-02-04"),
    SEENDTC = c("2024-01-05", "2024-01-10", "2024-02-04", "2024-02-10"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD",
                 group_by = list("USUBJID"))
  )
  # S1 row 1: "2024-01-05" == row2 SESTDTC "2024-01-05" -> pass
  # S1 row 2: last -> pass
  # S2 row 1: "2024-02-04" == row2 SESTDTC "2024-02-04" -> pass
  # S2 row 2: last -> pass
  expect_equal(out, c(FALSE, FALSE, FALSE, FALSE))
})

test_that("next_row_not_equal handles single-row groups without error", {
  d <- data.frame(
    USUBJID = c("S1"),
    TAETORD = c(1L),
    SESTDTC = c("2024-01-01"),
    SEENDTC = c("2024-01-05"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD",
                 group_by = list("USUBJID"))
  )
  expect_equal(out, FALSE)
})

test_that("next_row_not_equal returns NA for rows with NA in name or prev_name", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    TAETORD = c(1L, 2L, 3L),
    SESTDTC = c("2024-01-01", NA, "2024-01-07"),
    SEENDTC = c(NA, "2024-01-07", "2024-01-10"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD",
                 group_by = list("USUBJID"))
  )
  # Row 1: SEENDTC=NA -> NA
  # Row 2: SEENDTC="2024-01-07"; next SESTDTC="2024-01-07" -> pass (FALSE)
  # Row 3: last -> FALSE
  expect_true(is.na(out[[1L]]))
  expect_false(out[[2L]])
  expect_false(out[[3L]])
})

test_that("next_row_not_equal returns NA when name column absent", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    TAETORD = c(1L, 2L),
    SESTDTC = c("2024-01-01", "2024-01-05"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD",
                 group_by = list("USUBJID"))
  )
  expect_equal(out, c(NA, NA))
})

test_that("next_row_not_equal returns NA when prev_name column absent", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    TAETORD = c(1L, 2L),
    SEENDTC = c("2024-01-03", "2024-01-07"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD",
                 group_by = list("USUBJID"))
  )
  expect_equal(out, c(NA, NA))
})

test_that("next_row_not_equal returns NA when group_by column absent", {
  d <- data.frame(
    TAETORD = c(1L, 2L),
    SESTDTC = c("2024-01-01", "2024-01-03"),
    SEENDTC = c("2024-01-03", "2024-01-07"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD",
                 group_by = list("USUBJID"))
  )
  expect_equal(out, c(NA, NA))
})

test_that("next_row_not_equal handles empty dataset", {
  d <- data.frame(
    USUBJID = character(0L),
    TAETORD = integer(0L),
    SESTDTC = character(0L),
    SEENDTC = character(0L),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD",
                 group_by = list("USUBJID"))
  )
  expect_length(out, 0L)
})

test_that("next_row_not_equal respects order_by sort for unsorted input", {
  # Rows are not in TAETORD order in the data.frame
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    TAETORD = c(3L,   1L,   2L),
    SESTDTC = c("2024-01-07", "2024-01-01", "2024-01-04"),
    SEENDTC = c("2024-01-10", "2024-01-04", "2024-01-07"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD",
                 group_by = list("USUBJID"))
  )
  # After sort by TAETORD: row2(TAETORD=1) -> row3(TAETORD=2) -> row1(TAETORD=3)
  # Sorted row1 (orig row2): SEENDTC="2024-01-04" == next SESTDTC "2024-01-04" -> pass
  # Sorted row2 (orig row3): SEENDTC="2024-01-07" == next SESTDTC "2024-01-07" -> pass
  # Sorted row3 (orig row1): last -> pass
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

test_that("next_row_not_equal works without group_by (single global group)", {
  d <- data.frame(
    TAETORD = c(1L, 2L),
    SESTDTC = c("2024-01-01", "2024-01-05"),
    SEENDTC = c("2024-01-04", "2024-01-10"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d, ctx_empty,
    name  = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD")
  )
  # Row 1: "2024-01-04" != "2024-01-05" -> fires
  # Row 2: last -> pass
  expect_equal(out, c(TRUE, FALSE))
})
