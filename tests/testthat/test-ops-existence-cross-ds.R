# Tests for op_exists DS.VAR cross-dataset column presence (Q7).

test_that("op_exists DS.VAR fires when column exists in ref dataset", {
  ae <- data.frame(USUBJID = "S1", AESTDY = 1L, stringsAsFactors = FALSE)
  adae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae))
  out <- herald:::op_exists(adae, ctx, name = "AE.AESTDY")
  expect_true(isTRUE(out[[1L]]))
  expect_equal(length(out), nrow(adae))
})

test_that("op_exists DS.VAR returns FALSE when column absent from ref dataset", {
  ae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  adae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae))
  out <- herald:::op_exists(adae, ctx, name = "AE.AESTDY")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_exists DS.VAR returns FALSE when ref dataset absent", {
  adae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list())
  out <- herald:::op_exists(adae, ctx, name = "AE.AESTDY")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_exists DS.VAR produces dataset-level mask (only row 1 TRUE)", {
  ae <- data.frame(USUBJID = c("S1", "S2"), AESTDY = 1:2L,
                   stringsAsFactors = FALSE)
  adae <- data.frame(USUBJID = c("S1", "S2", "S3"), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae))
  out <- herald:::op_exists(adae, ctx, name = "AE.AESTDY")
  expect_equal(length(out), 3L)
  expect_true(isTRUE(out[[1L]]))
  expect_false(any(out[-1L], na.rm = TRUE))
})

test_that("op_exists DS.VAR is case-insensitive on ref ds and column", {
  ae <- data.frame(USUBJID = "S1", AESTDY = 1L, stringsAsFactors = FALSE)
  adae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae))
  # lowercase column name in ref ds
  ae2 <- data.frame(USUBJID = "S1", aestdy = 1L, stringsAsFactors = FALSE)
  ctx2 <- list(datasets = list(AE = ae2))
  out2 <- herald:::op_exists(adae, ctx2, name = "AE.AESTDY")
  expect_true(isTRUE(out2[[1L]]))
})

test_that("op_exists still handles plain column name (no regression)", {
  df <- data.frame(AESTDY = 1L, USUBJID = "S1", stringsAsFactors = FALSE)
  out <- herald:::op_exists(df, list(), name = "AESTDY")
  expect_true(all(out))
  out2 <- herald:::op_exists(df, list(), name = "ABSENT")
  expect_false(any(out2))
})

test_that("op_exists still handles dataset-ref (no regression)", {
  df <- data.frame(PARAMCD = "X", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = data.frame(USUBJID = "S1")))
  out <- herald:::op_exists(df, ctx, name = "AE")
  expect_true(isTRUE(out[[1L]]))
})
