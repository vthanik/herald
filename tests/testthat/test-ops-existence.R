# Tests for R/ops-existence.R

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

mk_data <- function() {
  data.frame(
    USUBJID = c("S1", "S2", NA_character_, ""),
    AGE = c(65L, NA_integer_, 42L, 30L),
    stringsAsFactors = FALSE
  )
}

# Build a ctx with a spec entry for ds_name -> class.
.q25_ctx <- function(ds_name, class = NULL) {
  spec <- if (!is.null(class)) {
    list(
      ds_spec = data.frame(
        dataset = ds_name,
        class = class,
        stringsAsFactors = FALSE
      )
    )
  } else {
    NULL
  }
  list(current_dataset = ds_name, spec = spec, datasets = list())
}

# =============================================================================
# Basic existence / emptiness ops
# =============================================================================

test_that("exists returns TRUE/FALSE for whole dataset", {
  d <- mk_data()
  expect_equal(op_exists(d, NULL, "USUBJID"), rep(TRUE, 4L))
  expect_equal(op_exists(d, NULL, "NOPE"), rep(FALSE, 4L))
})

test_that("not_exists is the inverse", {
  d <- mk_data()
  expect_equal(op_not_exists(d, NULL, "USUBJID"), rep(FALSE, 4L))
  expect_equal(op_not_exists(d, NULL, "NOPE"), rep(TRUE, 4L))
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
  expect_equal(op_empty(d, NULL, "AGE"), c(FALSE, TRUE, FALSE, FALSE))
})

test_that("is_missing / is_present are synonyms", {
  d <- mk_data()
  expect_equal(op_is_missing(d, NULL, "USUBJID"), op_empty(d, NULL, "USUBJID"))
  expect_equal(
    op_is_present(d, NULL, "USUBJID"),
    op_non_empty(d, NULL, "USUBJID")
  )
})

test_that("missing column returns NA mask", {
  d <- mk_data()
  expect_equal(op_non_empty(d, NULL, "NONEXISTENT"), rep(NA, 4L))
  expect_equal(op_empty(d, NULL, "NONEXISTENT"), rep(NA, 4L))
})

test_that("dataset-level not_exists collapses to a single fire when dataset missing", {
  ae <- data.frame(USUBJID = c("S1", "S2", "S3"), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae))
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
  ae <- data.frame(
    EX = c(1, 2, 3),
    USUBJID = c("a", "b", "c"),
    stringsAsFactors = FALSE
  )
  ctx <- list(datasets = list(AE = ae))
  expect_equal(op_exists(ae, ctx, "EX"), rep(TRUE, 3L))
  expect_equal(op_not_exists(ae, ctx, "EX"), rep(FALSE, 3L))
})

test_that("empty/non_empty treat trailing-whitespace-only strings as null (P21 rtrim convention)", {
  d <- data.frame(
    x = c("", "   ", "text", "text   ", "   leading", "0", "NA", "null", "n/a"),
    stringsAsFactors = FALSE
  )
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

# =============================================================================
# op_exists DS.VAR cross-dataset column presence (Q7)
# =============================================================================

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
  ae <- data.frame(
    USUBJID = c("S1", "S2"),
    AESTDY = 1:2L,
    stringsAsFactors = FALSE
  )
  adae <- data.frame(USUBJID = c("S1", "S2", "S3"), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae))
  out <- herald:::op_exists(adae, ctx, name = "AE.AESTDY")
  expect_equal(length(out), 3L)
  expect_true(isTRUE(out[[1L]]))
  expect_false(any(out[-1L], na.rm = TRUE))
})

test_that("op_exists DS.VAR is case-insensitive on ref ds and column", {
  ae2 <- data.frame(USUBJID = "S1", aestdy = 1L, stringsAsFactors = FALSE)
  adae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
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

# =============================================================================
# op_var_present_in_any_other_dataset (Q26)
# =============================================================================

test_that("returns TRUE when column present in another dataset (exact match)", {
  ae <- data.frame(
    AELNKGRP = c("G1", "G2"),
    USUBJID = c("S1", "S1"),
    stringsAsFactors = FALSE
  )
  mh <- data.frame(MHLNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, MH = mh), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    ctx,
    name = "AELNKGRP"
  )
  expect_true(isTRUE(out[[1L]]))
  expect_equal(length(out), nrow(ae))
})

test_that("returns FALSE when column absent from all other datasets", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  cm <- data.frame(CMTRT = "ASPIRIN", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, CM = cm), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    ctx,
    name = "AELNKGRP"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("suffix match: finds MHLNKGRP when searching AELNKGRP (same suffix)", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  mh <- data.frame(MHLNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, MH = mh), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    ctx,
    name = "AELNKGRP"
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("suffix match does not fire on different suffix", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  cm <- data.frame(CMLNKID = "ID-1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, CM = cm), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    ctx,
    name = "AELNKGRP"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("returns dataset-level mask (first row TRUE/FALSE, rest FALSE)", {
  ae <- data.frame(
    AELNKGRP = c("G1", "G2", "G3"),
    USUBJID = c("S1", "S2", "S3"),
    stringsAsFactors = FALSE
  )
  cm <- data.frame(CMTRT = "ASPIRIN", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, CM = cm), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    ctx,
    name = "AELNKGRP"
  )
  expect_equal(length(out), 3L)
  expect_false(isTRUE(out[[1L]]))
  expect_false(any(out[-1L], na.rm = TRUE))
})

test_that("returns NA advisory when ctx$datasets is NULL", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    list(datasets = NULL),
    name = "AELNKGRP"
  )
  expect_true(is.na(out[[1L]]))
})

test_that("returns NA advisory when ctx$datasets is empty", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    list(datasets = list()),
    name = "AELNKGRP"
  )
  expect_true(is.na(out[[1L]]))
})

test_that("returns NA advisory when no other datasets after excluding current", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    ctx,
    name = "AELNKGRP"
  )
  expect_true(is.na(out[[1L]]))
})

test_that("exclude_current=FALSE includes current dataset in search", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    ctx,
    name = "AELNKGRP",
    exclude_current = FALSE
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("handles empty data frame gracefully", {
  ae <- data.frame(
    AELNKGRP = character(0),
    USUBJID = character(0),
    stringsAsFactors = FALSE
  )
  cm <- data.frame(CMTRT = character(0), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, CM = cm), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    ctx,
    name = "AELNKGRP"
  )
  expect_equal(length(out), 0L)
})

test_that("empty name returns FALSE mask", {
  ae <- data.frame(AELNKGRP = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(
    datasets = list(AE = ae, CM = data.frame(CMTRT = "X")),
    current_dataset = "AE"
  )
  out <- herald:::op_var_present_in_any_other_dataset(ae, ctx, name = "")
  expect_false(isTRUE(out[[1L]]))
})

test_that("column comparison is case-insensitive", {
  ae <- data.frame(aelnkgrp = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  mh <- data.frame(mhlnkgrp = "G1", USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, MH = mh), current_dataset = "AE")
  out <- herald:::op_var_present_in_any_other_dataset(
    ae,
    ctx,
    name = "AELNKGRP"
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("op_var_present_in_any_other_dataset is registered", {
  meta <- herald:::.op_meta("var_present_in_any_other_dataset")
  expect_false(is.null(meta))
  expect_equal(meta$kind, "cross")
})

# =============================================================================
# op_dataset_name_prefix_not (Q25, ADaM-496/497)
# =============================================================================

test_that("ADaM-496: fires when name lacks prefix and spec class is non-missing", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("NONADT", class = "BASIC DATA STRUCTURE")
  out <- herald:::op_dataset_name_prefix_not(
    df,
    ctx,
    prefix = "AD",
    when_class_is_missing = FALSE
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("ADaM-496: silent when name starts with prefix and spec class is non-missing", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("ADEFF", class = "BASIC DATA STRUCTURE")
  out <- herald:::op_dataset_name_prefix_not(
    df,
    ctx,
    prefix = "AD",
    when_class_is_missing = FALSE
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("ADaM-496: silent when name lacks prefix but spec class is missing", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("NONADT", class = NULL)
  out <- herald:::op_dataset_name_prefix_not(
    df,
    ctx,
    prefix = "AD",
    when_class_is_missing = FALSE
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("ADaM-497: fires when name starts with prefix and spec class is missing", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("ADEFF", class = NULL)
  out <- herald:::op_dataset_name_prefix_not(
    df,
    ctx,
    prefix = "AD",
    when_class_is_missing = TRUE
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("ADaM-497: silent when name starts with prefix and spec class is non-missing", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("ADEFF", class = "BASIC DATA STRUCTURE")
  out <- herald:::op_dataset_name_prefix_not(
    df,
    ctx,
    prefix = "AD",
    when_class_is_missing = TRUE
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("ADaM-497: silent when name lacks prefix and spec class is missing", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("NONADT", class = NULL)
  out <- herald:::op_dataset_name_prefix_not(
    df,
    ctx,
    prefix = "AD",
    when_class_is_missing = TRUE
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_dataset_name_prefix_not returns dataset-level mask for multi-row data", {
  df <- data.frame(USUBJID = c("S1", "S2", "S3"), stringsAsFactors = FALSE)
  ctx <- .q25_ctx("NONADT", class = "BASIC DATA STRUCTURE")
  out <- herald:::op_dataset_name_prefix_not(
    df,
    ctx,
    prefix = "AD",
    when_class_is_missing = FALSE
  )
  expect_equal(length(out), 3L)
  expect_true(isTRUE(out[[1L]]))
  expect_false(any(out[-1L]))
})

test_that("op_dataset_name_prefix_not is case-insensitive on prefix and name", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("adeff", class = "BASIC DATA STRUCTURE")
  out <- herald:::op_dataset_name_prefix_not(
    df,
    ctx,
    prefix = "ad",
    when_class_is_missing = FALSE
  )
  expect_false(isTRUE(out[[1L]]))
})

# =============================================================================
# op_dataset_name_length_not_in_range (CG0017/CG0018/CG0205)
# =============================================================================

test_that("CG0017: fires when name is 2 chars (below min_len=3)", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "AE", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(
    df,
    ctx,
    min_len = 3L,
    max_len = 4L
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("CG0017: fires when name is 6 chars (above max_len=4)", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "AECLIN", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(
    df,
    ctx,
    min_len = 3L,
    max_len = 4L
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("CG0017: silent when name is 4 chars (within [3,4])", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "AESP", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(
    df,
    ctx,
    min_len = 3L,
    max_len = 4L
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("CG0018: fires when name has 9 chars (max_len=8)", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "AESP12345", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx, max_len = 8L)
  expect_true(isTRUE(out[[1L]]))
})

test_that("CG0018: silent when name is 6 chars (within max_len=8)", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "SUPPAE", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx, max_len = 8L)
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_dataset_name_length_not_in_range returns dataset-level mask", {
  df <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "AE", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(
    df,
    ctx,
    min_len = 3L,
    max_len = 4L
  )
  expect_equal(length(out), 2L)
  expect_true(isTRUE(out[[1L]]))
  expect_false(isTRUE(out[[2L]]))
})

test_that("op_dataset_name_length_not_in_range silent when ctx has no dataset name", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = NULL, spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx, max_len = 8L)
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_dataset_name_length_not_in_range: max_len only (NULL min_len)", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "SUPPQALX9", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx, max_len = 8L)
  expect_true(isTRUE(out[[1L]]))
})

# =============================================================================
# op_any_var_name_not_matching_regex (ADaM-14/15)
# =============================================================================

test_that("ADaM-14: fires when a var name does not start with letter", {
  df <- data.frame(`_BAD` = 1L, check.names = FALSE, stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(
    df,
    list(),
    value = "^[A-Z]"
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("ADaM-14: silent when all var names start with letter", {
  df <- data.frame(USUBJID = "S1", AGE = 30L, stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(
    df,
    list(),
    value = "^[A-Z]"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("ADaM-15: fires when a var name contains a disallowed character", {
  df <- data.frame(`A-B` = 1L, check.names = FALSE, stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(
    df,
    list(),
    value = "^[A-Z][A-Z0-9_]*$"
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("ADaM-15: silent when all var names contain only allowed characters", {
  df <- data.frame(USUBJID = "S1", AVAL = 1.0, stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(
    df,
    list(),
    value = "^[A-Z][A-Z0-9_]*$"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_any_var_name_not_matching_regex returns dataset-level mask", {
  df <- data.frame(
    `_BAD` = c(1L, 2L),
    GOOD = c(3L, 4L),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  out <- herald:::op_any_var_name_not_matching_regex(
    df,
    list(),
    value = "^[A-Z]"
  )
  expect_equal(length(out), 2L)
  expect_true(isTRUE(out[[1L]]))
  expect_false(any(out[-1L]))
})

test_that("op_any_var_name_not_matching_regex silent when regex is empty", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(df, list(), value = "")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_any_var_name_not_matching_regex silent when dataset has no columns", {
  df2 <- data.frame(stringsAsFactors = FALSE)[1L, , drop = FALSE]
  out <- herald:::op_any_var_name_not_matching_regex(
    df2,
    list(),
    value = "^[A-Z]"
  )
  expect_false(isTRUE(out[[1L]]))
})

# =============================================================================
# op_no_var_with_suffix (Q24, ADSL *FL presence)
# =============================================================================

test_that("op_no_var_with_suffix fires when no variable carries the suffix", {
  adsl <- data.frame(USUBJID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  out <- op_no_var_with_suffix(adsl, list(), suffix = "FL")
  expect_true(isTRUE(out[[1L]]))
})

test_that("op_no_var_with_suffix silent when any column matches", {
  adsl <- data.frame(USUBJID = "S1", SAFFL = "Y", stringsAsFactors = FALSE)
  out <- op_no_var_with_suffix(adsl, list(), suffix = "FL")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_no_var_with_suffix is case-insensitive on name + suffix", {
  adsl <- data.frame(usubjid = "S1", saffl = "Y", stringsAsFactors = FALSE)
  out <- op_no_var_with_suffix(adsl, list(), suffix = "fl")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_no_var_with_suffix returns a dataset-level mask", {
  adsl <- data.frame(USUBJID = c("S1", "S2", "S3"), stringsAsFactors = FALSE)
  out <- op_no_var_with_suffix(adsl, list(), suffix = "FL")
  expect_equal(length(out), 3L)
  expect_true(isTRUE(out[[1L]]))
  expect_false(any(out[-1L]))
})

test_that("op_no_var_with_suffix passes through when suffix empty", {
  adsl <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  out <- op_no_var_with_suffix(adsl, list(), suffix = "")
  expect_false(isTRUE(out[[1L]]))
})

# =============================================================================
# op_var_by_suffix_not_numeric (Q11, ADaM-58/59/60/716)
# =============================================================================

test_that("op_var_by_suffix_not_numeric fires when column is character", {
  df <- data.frame(
    EXSTDT = c("2020-01-01", "2020-02-01"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_var_by_suffix_not_numeric(df, list(), name = "EXSTDT")
  expect_true(all(out))
})

test_that("op_var_by_suffix_not_numeric passes when column is numeric", {
  df <- data.frame(EXSTDT = c(18000, 18001))
  out <- herald:::op_var_by_suffix_not_numeric(df, list(), name = "EXSTDT")
  expect_true(all(!out))
})

test_that("op_var_by_suffix_not_numeric returns NA when column absent", {
  df <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  out <- herald:::op_var_by_suffix_not_numeric(df, list(), name = "EXSTDT")
  expect_true(all(is.na(out)))
  expect_equal(length(out), 1L)
})

test_that("op_var_by_suffix_not_numeric passes when exclude_prefix matches", {
  df <- data.frame(ELTM = c("T12:00", "T13:00"), stringsAsFactors = FALSE)
  out <- herald:::op_var_by_suffix_not_numeric(
    df,
    list(),
    name = "ELTM",
    exclude_prefix = "EL"
  )
  expect_true(all(!out))
})

test_that("op_var_by_suffix_not_numeric fires when exclude_prefix does not match", {
  df <- data.frame(VSTM = c("T12:00", "T13:00"), stringsAsFactors = FALSE)
  out <- herald:::op_var_by_suffix_not_numeric(
    df,
    list(),
    name = "VSTM",
    exclude_prefix = "EL"
  )
  expect_true(all(out))
})

test_that("op_var_by_suffix_not_numeric empty exclude_prefix has no effect", {
  df <- data.frame(ELTM = c("T12:00"), stringsAsFactors = FALSE)
  out <- herald:::op_var_by_suffix_not_numeric(
    df,
    list(),
    name = "ELTM",
    exclude_prefix = ""
  )
  expect_true(all(out))
})
