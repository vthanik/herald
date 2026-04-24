# Tests for op_var_present_in_any_other_dataset (Q26).

# --- basic presence / absence ------------------------------------------------

test_that("returns TRUE when column present in another dataset (exact match)", {
  ae <- data.frame(AELNKGRP = c("G1", "G2"), USUBJID = c("S1", "S1"),
                   stringsAsFactors = FALSE)
  mh <- data.frame(MHLNKGRP = "G1", USUBJID = "S1",
                   stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, MH = mh), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "AELNKGRP")
  expect_true(isTRUE(out[[1L]]))
  expect_equal(length(out), nrow(ae))
})

test_that("returns FALSE when column absent from all other datasets", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  cm <- data.frame(CMTRT = "ASPIRIN", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, CM = cm), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "AELNKGRP")
  expect_false(isTRUE(out[[1L]]))
})

# --- suffix-based cross-domain match (--VAR wildcard scenario) ---------------

test_that("suffix match: finds MHLNKGRP when searching AELNKGRP (same suffix)", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  mh <- data.frame(MHLNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, MH = mh), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "AELNKGRP")
  expect_true(isTRUE(out[[1L]]))
})

test_that("suffix match does not fire on different suffix", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  cm <- data.frame(CMLNKID = "ID-1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, CM = cm), current_dataset = "AE")
  # AELNKGRP suffix = LNKGRP; CMLNKID suffix = LNKID -- different, no match
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "AELNKGRP")
  expect_false(isTRUE(out[[1L]]))
})

# --- dataset-level mask -------------------------------------------------------

test_that("returns dataset-level mask (first row TRUE/FALSE, rest FALSE)", {
  ae <- data.frame(AELNKGRP = c("G1", "G2", "G3"), USUBJID = c("S1", "S2", "S3"),
                   stringsAsFactors = FALSE)
  cm <- data.frame(CMTRT = "ASPIRIN", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, CM = cm), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "AELNKGRP")
  expect_equal(length(out), 3L)
  expect_false(isTRUE(out[[1L]]))
  expect_false(any(out[-1L], na.rm = TRUE))
})

# --- advisory path (no submission context) ------------------------------------

test_that("returns NA advisory when ctx$datasets is NULL", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  out <- herald:::op_var_present_in_any_other_dataset(ae, list(datasets = NULL),
                                                       name = "AELNKGRP")
  expect_true(is.na(out[[1L]]))
})

test_that("returns NA advisory when ctx$datasets is empty", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  out <- herald:::op_var_present_in_any_other_dataset(ae, list(datasets = list()),
                                                       name = "AELNKGRP")
  expect_true(is.na(out[[1L]]))
})

test_that("returns NA advisory when no other datasets after excluding current", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "AELNKGRP")
  expect_true(is.na(out[[1L]]))
})

# --- exclude_current = FALSE -------------------------------------------------

test_that("exclude_current=FALSE includes current dataset in search", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "AELNKGRP",
                                                       exclude_current = FALSE)
  # When we include the current dataset, AELNKGRP is found in AE itself
  expect_true(isTRUE(out[[1L]]))
})

# --- empty dataset -----------------------------------------------------------

test_that("handles empty data frame gracefully", {
  ae  <- data.frame(AELNKGRP = character(0), USUBJID = character(0),
                    stringsAsFactors = FALSE)
  cm  <- data.frame(CMTRT = character(0), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, CM = cm), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "AELNKGRP")
  expect_equal(length(out), 0L)
})

# --- edge: empty name arg ----------------------------------------------------

test_that("empty name returns FALSE mask", {
  ae  <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, CM = data.frame(CMTRT = "X")),
              current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "")
  expect_false(isTRUE(out[[1L]]))
})

# --- case-insensitive column matching ----------------------------------------

test_that("column comparison is case-insensitive", {
  ae <- data.frame(aelnkgrp = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  mh <- data.frame(mhlnkgrp = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, MH = mh), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "AELNKGRP")
  expect_true(isTRUE(out[[1L]]))
})

# --- op is registered --------------------------------------------------------

test_that("op_var_present_in_any_other_dataset is registered", {
  meta <- herald:::.op_meta("var_present_in_any_other_dataset")
  expect_false(is.null(meta))
  expect_equal(meta$kind, "cross")
})
