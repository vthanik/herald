# Tests for dataset-name / variable-name structural ops introduced in Q25:
#   op_dataset_name_prefix_not            (ADaM-496 / ADaM-497)
#   op_dataset_name_length_not_in_range   (CG0017 / CG0018 / CG0205)
#   op_any_var_name_not_matching_regex    (ADaM-14 / ADaM-15)

# Build a ctx with a spec entry for ds_name -> class.
.q25_ctx <- function(ds_name, class = NULL) {
  spec <- if (!is.null(class)) {
    list(ds_spec = data.frame(
      dataset = ds_name,
      class   = class,
      stringsAsFactors = FALSE
    ))
  } else {
    NULL
  }
  list(current_dataset = ds_name, spec = spec, datasets = list())
}

# ---------------------------------------------------------------------------
# op_dataset_name_prefix_not
# ---------------------------------------------------------------------------

test_that("ADaM-496: fires when name lacks prefix and spec class is non-missing", {
  # NONADT does not start with "AD"; spec supplies a class -> class is non-missing.
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("NONADT", class = "BASIC DATA STRUCTURE")
  out <- herald:::op_dataset_name_prefix_not(df, ctx,
                                              prefix = "AD",
                                              when_class_is_missing = FALSE)
  expect_true(isTRUE(out[[1L]]))
})

test_that("ADaM-496: silent when name starts with prefix and spec class is non-missing", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("ADEFF", class = "BASIC DATA STRUCTURE")
  out <- herald:::op_dataset_name_prefix_not(df, ctx,
                                              prefix = "AD",
                                              when_class_is_missing = FALSE)
  expect_false(isTRUE(out[[1L]]))
})

test_that("ADaM-496: silent when name lacks prefix but spec class is missing", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  # No spec -> class is missing -> ADaM-496 condition not met
  ctx <- .q25_ctx("NONADT", class = NULL)
  out <- herald:::op_dataset_name_prefix_not(df, ctx,
                                              prefix = "AD",
                                              when_class_is_missing = FALSE)
  expect_false(isTRUE(out[[1L]]))
})

test_that("ADaM-497: fires when name starts with prefix and spec class is missing", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  # No spec for ADEFF -> class is missing (spec-only lookup, no heuristic).
  ctx <- .q25_ctx("ADEFF", class = NULL)
  out <- herald:::op_dataset_name_prefix_not(df, ctx,
                                              prefix = "AD",
                                              when_class_is_missing = TRUE)
  expect_true(isTRUE(out[[1L]]))
})

test_that("ADaM-497: silent when name starts with prefix and spec class is non-missing", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("ADEFF", class = "BASIC DATA STRUCTURE")
  out <- herald:::op_dataset_name_prefix_not(df, ctx,
                                              prefix = "AD",
                                              when_class_is_missing = TRUE)
  expect_false(isTRUE(out[[1L]]))
})

test_that("ADaM-497: silent when name lacks prefix and spec class is missing", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("NONADT", class = NULL)
  out <- herald:::op_dataset_name_prefix_not(df, ctx,
                                              prefix = "AD",
                                              when_class_is_missing = TRUE)
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_dataset_name_prefix_not returns dataset-level mask for multi-row data", {
  df  <- data.frame(USUBJID = c("S1", "S2", "S3"), stringsAsFactors = FALSE)
  ctx <- .q25_ctx("NONADT", class = "BASIC DATA STRUCTURE")
  out <- herald:::op_dataset_name_prefix_not(df, ctx,
                                              prefix = "AD",
                                              when_class_is_missing = FALSE)
  expect_equal(length(out), 3L)
  expect_true(isTRUE(out[[1L]]))
  expect_false(any(out[-1L]))
})

test_that("op_dataset_name_prefix_not is case-insensitive on prefix and name", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- .q25_ctx("adeff", class = "BASIC DATA STRUCTURE")
  out <- herald:::op_dataset_name_prefix_not(df, ctx,
                                              prefix = "ad",
                                              when_class_is_missing = FALSE)
  expect_false(isTRUE(out[[1L]]))
})

# ---------------------------------------------------------------------------
# op_dataset_name_length_not_in_range
# ---------------------------------------------------------------------------

test_that("CG0017: fires when name is 2 chars (below min_len=3)", {
  # "AE" has length 2 which is less than min_len=3.
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "AE", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx,
                                                       min_len = 3L,
                                                       max_len = 4L)
  expect_true(isTRUE(out[[1L]]))
})

test_that("CG0017: fires when name is 6 chars (above max_len=4)", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "AECLIN", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx,
                                                       min_len = 3L,
                                                       max_len = 4L)
  expect_true(isTRUE(out[[1L]]))
})

test_that("CG0017: silent when name is 4 chars (within [3,4])", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "AESP", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx,
                                                       min_len = 3L,
                                                       max_len = 4L)
  expect_false(isTRUE(out[[1L]]))
})

test_that("CG0018: fires when name has 9 chars (max_len=8)", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "AESP12345", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx, max_len = 8L)
  expect_true(isTRUE(out[[1L]]))
})

test_that("CG0018: silent when name is 6 chars (within max_len=8)", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "SUPPAE", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx, max_len = 8L)
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_dataset_name_length_not_in_range returns dataset-level mask", {
  df  <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  # "AE" = 2 chars < min_len=3 -> fires
  ctx <- list(current_dataset = "AE", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx,
                                                       min_len = 3L,
                                                       max_len = 4L)
  expect_equal(length(out), 2L)
  expect_true(isTRUE(out[[1L]]))
  expect_false(isTRUE(out[[2L]]))
})

test_that("op_dataset_name_length_not_in_range silent when ctx has no dataset name", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = NULL, spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx, max_len = 8L)
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_dataset_name_length_not_in_range: max_len only (NULL min_len)", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ctx <- list(current_dataset = "SUPPQALX9", spec = NULL, datasets = list())
  out <- herald:::op_dataset_name_length_not_in_range(df, ctx, max_len = 8L)
  expect_true(isTRUE(out[[1L]]))
})

# ---------------------------------------------------------------------------
# op_any_var_name_not_matching_regex
# ---------------------------------------------------------------------------

test_that("ADaM-14: fires when a var name does not start with letter", {
  df  <- data.frame(`_BAD` = 1L, check.names = FALSE, stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(df, list(), value = "^[A-Z]")
  expect_true(isTRUE(out[[1L]]))
})

test_that("ADaM-14: silent when all var names start with letter", {
  df  <- data.frame(USUBJID = "S1", AGE = 30L, stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(df, list(), value = "^[A-Z]")
  expect_false(isTRUE(out[[1L]]))
})

test_that("ADaM-15: fires when a var name contains a disallowed character", {
  df  <- data.frame(`A-B` = 1L, check.names = FALSE, stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(df, list(), value = "^[A-Z][A-Z0-9_]*$")
  expect_true(isTRUE(out[[1L]]))
})

test_that("ADaM-15: silent when all var names contain only allowed characters", {
  df  <- data.frame(USUBJID = "S1", AVAL = 1.0, stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(df, list(), value = "^[A-Z][A-Z0-9_]*$")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_any_var_name_not_matching_regex returns dataset-level mask", {
  # Two rows; _BAD violates the regex -> fires on row 1 only (dataset-level).
  df  <- data.frame(`_BAD` = c(1L, 2L), GOOD = c(3L, 4L),
                    check.names = FALSE, stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(df, list(), value = "^[A-Z]")
  expect_equal(length(out), 2L)
  expect_true(isTRUE(out[[1L]]))
  expect_false(any(out[-1L]))
})

test_that("op_any_var_name_not_matching_regex silent when regex is empty", {
  df  <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  out <- herald:::op_any_var_name_not_matching_regex(df, list(), value = "")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_any_var_name_not_matching_regex silent when dataset has no columns", {
  df  <- data.frame(stringsAsFactors = FALSE)
  df  <- df[seq_len(0), , drop = FALSE]
  # Add one row artificially to avoid 0-row issue
  df2 <- data.frame(stringsAsFactors = FALSE)[1L, , drop = FALSE]
  out <- herald:::op_any_var_name_not_matching_regex(df2, list(), value = "^[A-Z]")
  # 0 columns -> no fire
  expect_false(isTRUE(out[[1L]]))
})
