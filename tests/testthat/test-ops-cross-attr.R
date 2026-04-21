# Tests for the attr-reading ops added to R/ops-cross.R:
#   op_attr_mismatch
#   op_shared_attr_mismatch
#   op_dataset_label_not
#   op_treatment_var_absent_across_datasets
#   op_value_not_in_subject_indexed_set

.ctx <- function(...) list(datasets = list(...))

.with_label <- function(df, col, label) {
  attr(df[[col]], "label") <- label
  df
}

# ---- op_attr_mismatch ------------------------------------------------------

test_that("op_attr_mismatch fires when labels differ", {
  dm   <- .with_label(data.frame(AGE = 65L),  "AGE", "Age Years")
  adsl <- .with_label(data.frame(AGE = 65L),  "AGE", "Age at Screening")
  out  <- op_attr_mismatch(dm, .ctx(DM = dm, ADSL = adsl),
                           name = "AGE", attribute = "label",
                           reference_dataset = "ADSL")
  expect_true(isTRUE(out[[1L]]))
})

test_that("op_attr_mismatch is silent when labels match", {
  dm   <- .with_label(data.frame(AGE = 65L), "AGE", "Age")
  adsl <- .with_label(data.frame(AGE = 65L), "AGE", "Age")
  out  <- op_attr_mismatch(dm, .ctx(DM = dm, ADSL = adsl),
                           name = "AGE", attribute = "label",
                           reference_dataset = "ADSL")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_attr_mismatch returns NA when attribute missing on either side", {
  dm   <- .with_label(data.frame(AGE = 65L), "AGE", "Age")
  adsl <- data.frame(AGE = 65L)  # no label attr
  out  <- op_attr_mismatch(dm, .ctx(DM = dm, ADSL = adsl),
                           name = "AGE", attribute = "label",
                           reference_dataset = "ADSL")
  expect_true(all(is.na(out)))
})

test_that("op_attr_mismatch returns NA when reference dataset missing", {
  dm <- .with_label(data.frame(AGE = 65L), "AGE", "Age")
  out <- op_attr_mismatch(dm, .ctx(DM = dm),
                          name = "AGE", attribute = "label",
                          reference_dataset = "ADSL")
  expect_true(all(is.na(out)))
})

test_that("op_attr_mismatch resolves friendly attribute names", {
  dm   <- data.frame(AGE = 65L); attr(dm$AGE, "format.sas") <- "8."
  adsl <- data.frame(AGE = 65L); attr(adsl$AGE, "format.sas") <- "Z8."
  out  <- op_attr_mismatch(dm, .ctx(DM = dm, ADSL = adsl),
                           name = "AGE", attribute = "format",
                           reference_dataset = "ADSL")
  expect_true(isTRUE(out[[1L]]))
})

# ---- op_shared_attr_mismatch ----------------------------------------------

test_that("op_shared_attr_mismatch fires when any shared column differs", {
  dm   <- .with_label(data.frame(USUBJID = "S1", AGE = 65L),
                      "AGE", "Age Y")
  adsl <- .with_label(data.frame(USUBJID = "S1", AGE = 65L),
                      "AGE", "Age at Screening")
  adsl <- .with_label(adsl, "USUBJID", "Unique Subject Identifier")
  dm   <- .with_label(dm,   "USUBJID", "Unique Subject Identifier")
  out  <- op_shared_attr_mismatch(dm, .ctx(DM = dm, ADSL = adsl),
                                  attribute = "label",
                                  reference_dataset = "ADSL")
  expect_true(isTRUE(out[[1L]]))
})

test_that("op_shared_attr_mismatch silent when all shared labels match", {
  dm   <- .with_label(data.frame(USUBJID = "S1"), "USUBJID", "USUBJID label")
  adsl <- .with_label(data.frame(USUBJID = "S1"), "USUBJID", "USUBJID label")
  out  <- op_shared_attr_mismatch(dm, .ctx(DM = dm, ADSL = adsl),
                                  attribute = "label",
                                  reference_dataset = "ADSL")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_shared_attr_mismatch respects exclude", {
  dm   <- .with_label(data.frame(USUBJID = "S1", AGE = 65L),
                      "AGE", "Age DM")
  adsl <- .with_label(data.frame(USUBJID = "S1", AGE = 65L),
                      "AGE", "Age ADSL")
  out  <- op_shared_attr_mismatch(dm, .ctx(DM = dm, ADSL = adsl),
                                  attribute = "label",
                                  reference_dataset = "ADSL",
                                  exclude = "AGE")
  expect_false(isTRUE(out[[1L]]))
})

# ---- op_dataset_label_not --------------------------------------------------

test_that("op_dataset_label_not fires on label mismatch", {
  adsl <- data.frame(USUBJID = "S1")
  attr(adsl, "label") <- "Wrong Label"
  out <- op_dataset_label_not(adsl, list(),
                              expected = "Subject-Level Analysis Dataset")
  expect_true(isTRUE(out[[1L]]))
})

test_that("op_dataset_label_not passes when labels match (trimmed, CI)", {
  adsl <- data.frame(USUBJID = "S1")
  attr(adsl, "label") <- " subject-level analysis dataset "
  out <- op_dataset_label_not(adsl, list(),
                              expected = "Subject-Level Analysis Dataset")
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_dataset_label_not returns NA when label attr missing", {
  adsl <- data.frame(USUBJID = "S1")
  out <- op_dataset_label_not(adsl, list(), expected = "X")
  expect_true(all(is.na(out)))
})

# ---- op_treatment_var_absent_across_datasets ------------------------------

test_that("treatment-absent fires when both sides lack treatment vars", {
  adae <- data.frame(USUBJID = "S1", AEDECOD = "X", stringsAsFactors = FALSE)
  adsl <- data.frame(USUBJID = "S1",                 stringsAsFactors = FALSE)
  out  <- op_treatment_var_absent_across_datasets(
    adae, .ctx(ADAE = adae, ADSL = adsl),
    current_vars   = list("TRTP", "TRTA"),
    reference_vars = list("TRTxxP", "TRTxxA"),
    reference_dataset = "ADSL"
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("treatment-absent passes when current dataset has TRTP", {
  adae <- data.frame(USUBJID = "S1", TRTP = "PLAC", stringsAsFactors = FALSE)
  adsl <- data.frame(USUBJID = "S1",                 stringsAsFactors = FALSE)
  out  <- op_treatment_var_absent_across_datasets(
    adae, .ctx(ADAE = adae, ADSL = adsl),
    current_vars   = list("TRTP", "TRTA"),
    reference_vars = list("TRTxxP")
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("treatment-absent passes when ADSL has TRT01P", {
  adae <- data.frame(USUBJID = "S1", AEDECOD = "X", stringsAsFactors = FALSE)
  adsl <- data.frame(USUBJID = "S1", TRT01P = "PLAC", stringsAsFactors = FALSE)
  out  <- op_treatment_var_absent_across_datasets(
    adae, .ctx(ADAE = adae, ADSL = adsl),
    current_vars   = list("TRTP"),
    reference_vars = list("TRTxxP")
  )
  expect_false(isTRUE(out[[1L]]))
})

# ---- op_value_not_in_subject_indexed_set ----------------------------------

test_that("value-not-in-set fires when row value absent from subject set", {
  adsl <- data.frame(
    USUBJID = c("S1", "S2"),
    TRT01P  = c("PLAC", "DRUG"),
    TRT02P  = c("DRUG", NA),
    stringsAsFactors = FALSE
  )
  adae <- data.frame(
    USUBJID = c("S1", "S1", "S2"),
    TRTP    = c("PLAC", "DRUG", "OTHER"),
    stringsAsFactors = FALSE
  )
  out <- op_value_not_in_subject_indexed_set(
    adae, .ctx(ADSL = adsl, ADAE = adae),
    name = "TRTP", reference_dataset = "ADSL",
    reference_template = "TRTxxP"
  )
  expect_equal(out, c(FALSE, FALSE, TRUE))
})

test_that("value-not-in-set returns NA when subject not in reference", {
  adsl <- data.frame(USUBJID = "S1", TRT01P = "PLAC", stringsAsFactors = FALSE)
  adae <- data.frame(USUBJID = "S9", TRTP = "X",      stringsAsFactors = FALSE)
  out  <- op_value_not_in_subject_indexed_set(
    adae, .ctx(ADSL = adsl, ADAE = adae),
    name = "TRTP", reference_dataset = "ADSL",
    reference_template = "TRTxxP"
  )
  expect_true(all(is.na(out)))
})

test_that("value-not-in-set returns NA when template matches no columns", {
  adsl <- data.frame(USUBJID = "S1", FOO = "X", stringsAsFactors = FALSE)
  adae <- data.frame(USUBJID = "S1", TRTP = "X", stringsAsFactors = FALSE)
  out  <- op_value_not_in_subject_indexed_set(
    adae, .ctx(ADSL = adsl, ADAE = adae),
    name = "TRTP", reference_dataset = "ADSL",
    reference_template = "TRTxxP"
  )
  expect_true(all(is.na(out)))
})

test_that("shared_values_mismatch_by_key fires on per-row value mismatch", {
  adsl <- data.frame(USUBJID = c("S1","S2"), AGE = c(65L,72L),
                     SEX = c("M","F"), stringsAsFactors = FALSE)
  cur  <- data.frame(USUBJID = c("S1","S2","S2"), AGE = c(65L,72L,80L),
                     SEX = c("M","F","F"), stringsAsFactors = FALSE)
  out  <- op_shared_values_mismatch_by_key(
    cur, .ctx(ADSL = adsl, CUR = cur),
    reference_dataset = "ADSL"
  )
  expect_equal(out, c(FALSE, FALSE, TRUE))
})

test_that("shared_values_mismatch_by_key returns NA when subject absent in ref", {
  adsl <- data.frame(USUBJID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  cur  <- data.frame(USUBJID = "S9", AGE = 90L, stringsAsFactors = FALSE)
  out  <- op_shared_values_mismatch_by_key(
    cur, .ctx(ADSL = adsl, CUR = cur),
    reference_dataset = "ADSL"
  )
  expect_true(all(is.na(out)))
})

test_that("shared_values_mismatch_by_key honours exclude list", {
  adsl <- data.frame(USUBJID = "S1", AGE = 65L, SEX = "M",
                     stringsAsFactors = FALSE)
  cur  <- data.frame(USUBJID = "S1", AGE = 99L, SEX = "M",
                     stringsAsFactors = FALSE)
  out  <- op_shared_values_mismatch_by_key(
    cur, .ctx(ADSL = adsl, CUR = cur),
    reference_dataset = "ADSL", exclude = "AGE"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("not_equal_subject_templated_ref fires per-row datetime mismatch", {
  adsl <- data.frame(
    USUBJID = "S1",
    P01S1SDM = "2024-01-01",
    P01S2SDM = "2024-03-01",
    stringsAsFactors = FALSE
  )
  bds <- data.frame(
    USUBJID = c("S1","S1","S1"),
    APERIOD = c(1L, 1L, 1L),
    ASPER   = c(1L, 2L, 2L),
    ASPRSDTM = c("2024-01-01", "2024-03-01", "WRONG"),
    stringsAsFactors = FALSE
  )
  out <- op_not_equal_subject_templated_ref(
    bds, .ctx(ADSL = adsl, BDS = bds),
    name = "ASPRSDTM",
    reference_dataset = "ADSL",
    reference_template = "PxxSwSDM",
    index_cols = list(xx = "APERIOD", w = "ASPER")
  )
  expect_equal(out, c(FALSE, FALSE, TRUE))
})

test_that("not_equal_subject_templated_ref returns NA when resolved column absent", {
  adsl <- data.frame(USUBJID = "S1", P01S1SDM = "2024-01-01",
                     stringsAsFactors = FALSE)
  bds <- data.frame(USUBJID = "S1", APERIOD = 2L, ASPER = 1L,
                    ASPRSDTM = "2024-05-01",
                    stringsAsFactors = FALSE)
  out <- op_not_equal_subject_templated_ref(
    bds, .ctx(ADSL = adsl, BDS = bds),
    name = "ASPRSDTM", reference_dataset = "ADSL",
    reference_template = "PxxSwSDM",
    index_cols = list(xx = "APERIOD", w = "ASPER")
  )
  expect_true(all(is.na(out)))
})

test_that("not_equal_subject_templated_ref returns NA on NA index value", {
  adsl <- data.frame(USUBJID = "S1", P01S1SDM = "2024-01-01",
                     stringsAsFactors = FALSE)
  bds <- data.frame(USUBJID = "S1", APERIOD = NA_integer_, ASPER = 1L,
                    ASPRSDTM = "2024-01-01",
                    stringsAsFactors = FALSE)
  out <- op_not_equal_subject_templated_ref(
    bds, .ctx(ADSL = adsl, BDS = bds),
    name = "ASPRSDTM", reference_dataset = "ADSL",
    reference_template = "PxxSwSDM",
    index_cols = list(xx = "APERIOD", w = "ASPER")
  )
  expect_true(all(is.na(out)))
})

test_that("value-not-in-set honours compound templates (PxxSw)", {
  adsl <- data.frame(
    USUBJID = "S1",
    P01S1 = "A", P01S2 = "B",
    P02S1 = "C",
    stringsAsFactors = FALSE
  )
  cur <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    ASPER   = c("A", "C", "Z"),
    stringsAsFactors = FALSE
  )
  out <- op_value_not_in_subject_indexed_set(
    cur, .ctx(ADSL = adsl, CUR = cur),
    name = "ASPER", reference_dataset = "ADSL",
    reference_template = "PxxSw"
  )
  expect_equal(out, c(FALSE, FALSE, TRUE))
})
