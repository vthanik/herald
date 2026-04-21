# -----------------------------------------------------------------------------
# test-fast-ops-join.R -- differs_by_key / matches_by_key operators
# -----------------------------------------------------------------------------

mk_ctx_with <- function(datasets) {
  ctx <- new_herald_ctx()
  ctx$datasets <- datasets
  ctx
}

test_that("differs_by_key fires where joined value diverges", {
  ae <- data.frame(
    VISITNUM = c(1, 2, 3),
    VISITDY  = c(1, 8, 99),  # row 3 diverges
    stringsAsFactors = FALSE
  )
  tv <- data.frame(
    VISITNUM = c(1, 2, 3),
    VISITDY  = c(1, 8, 15),
    stringsAsFactors = FALSE
  )
  ctx <- mk_ctx_with(list(AE = ae, TV = tv))

  mask <- op_differs_by_key(ae, ctx, name = "VISITDY",
                            reference_dataset = "TV",
                            reference_column  = "VISITDY",
                            key = "VISITNUM")
  expect_equal(mask, c(FALSE, FALSE, TRUE))
})

test_that("matches_by_key is the inverse of differs_by_key", {
  ae <- data.frame(VISITNUM = c(1, 2), VISITDY = c(1, 99),
                   stringsAsFactors = FALSE)
  tv <- data.frame(VISITNUM = c(1, 2), VISITDY = c(1, 8),
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx_with(list(AE = ae, TV = tv))
  expect_equal(
    op_matches_by_key(ae, ctx, "VISITDY",
                      reference_dataset = "TV",
                      reference_column  = "VISITDY",
                      key = "VISITNUM"),
    c(TRUE, FALSE)
  )
})

test_that("differs_by_key returns NA when the row's key has no match in ref", {
  ae <- data.frame(VISITNUM = c(1, 99), VISITDY = c(1, 1),
                   stringsAsFactors = FALSE)
  tv <- data.frame(VISITNUM = c(1, 2), VISITDY = c(1, 8),
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx_with(list(AE = ae, TV = tv))
  mask <- op_differs_by_key(ae, ctx, "VISITDY",
                            reference_dataset = "TV",
                            reference_column  = "VISITDY",
                            key = "VISITNUM")
  expect_equal(mask, c(FALSE, NA))
})

test_that("differs_by_key returns NA mask when the reference dataset is missing", {
  ae <- data.frame(VISITNUM = c(1, 2), VISITDY = c(1, 8),
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx_with(list(AE = ae))  # no TV
  mask <- op_differs_by_key(ae, ctx, "VISITDY",
                            reference_dataset = "TV",
                            reference_column  = "VISITDY",
                            key = "VISITNUM")
  expect_equal(mask, rep(NA, 2L))
})

test_that("differs_by_key accepts a distinct reference_key", {
  # In the current dataset the key column is VISITNUM; in the reference it's
  # called VISITNO (a fictional mismatch for test purposes).
  sv <- data.frame(VISITNUM = c(1, 2), VISITDY = c(1, 8),
                   stringsAsFactors = FALSE)
  tv <- data.frame(VISITNO = c(1, 2), VISITDY = c(1, 8),
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx_with(list(SV = sv, TV = tv))
  mask <- op_differs_by_key(sv, ctx, "VISITDY",
                            reference_dataset = "TV",
                            reference_column  = "VISITDY",
                            key = "VISITNUM",
                            reference_key = "VISITNO")
  expect_equal(mask, c(FALSE, FALSE))
})

test_that("differs_by_key defaults key to `name` when omitted", {
  # Joining AE.USUBJID against DM.USUBJID (same column name); compare
  # AE.SEX against DM.SEX (placeholder).
  ae <- data.frame(USUBJID = c("S1","S2"), SEX = c("M","F"),
                   stringsAsFactors = FALSE)
  dm <- data.frame(USUBJID = c("S1","S2"), SEX = c("M","M"),  # S2 diverges
                   stringsAsFactors = FALSE)
  ctx <- mk_ctx_with(list(AE = ae, DM = dm))
  mask <- op_differs_by_key(ae, ctx, "SEX",
                            reference_dataset = "DM",
                            reference_column  = "SEX",
                            key = "USUBJID")
  expect_equal(mask, c(FALSE, TRUE))
})

test_that("both ops are discoverable via the op table", {
  expect_true("differs_by_key" %in% .list_ops())
  expect_true("matches_by_key" %in% .list_ops())
})
