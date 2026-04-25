# Tests for R/ops-cross.R

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

.ctx <- function(...) list(datasets = list(...))

.with_label <- function(df, col, label) {
  attr(df[[col]], "label") <- label
  df
}

.mk_ctx_with <- function(datasets) {
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- datasets
  ctx
}

.mk_ctx_empty <- function() {
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list()
  ctx
}

ctx_empty <- .mk_ctx_empty()

# =============================================================================
# op_attr_mismatch
# =============================================================================

test_that("op_attr_mismatch fires when labels differ", {
  dm <- .with_label(data.frame(AGE = 65L), "AGE", "Age Years")
  adsl <- .with_label(data.frame(AGE = 65L), "AGE", "Age at Screening")
  out <- op_attr_mismatch(
    dm,
    .ctx(DM = dm, ADSL = adsl),
    name = "AGE",
    attribute = "label",
    reference_dataset = "ADSL"
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("op_attr_mismatch is silent when labels match", {
  dm <- .with_label(data.frame(AGE = 65L), "AGE", "Age")
  adsl <- .with_label(data.frame(AGE = 65L), "AGE", "Age")
  out <- op_attr_mismatch(
    dm,
    .ctx(DM = dm, ADSL = adsl),
    name = "AGE",
    attribute = "label",
    reference_dataset = "ADSL"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_attr_mismatch returns NA when attribute missing on either side", {
  dm <- .with_label(data.frame(AGE = 65L), "AGE", "Age")
  adsl <- data.frame(AGE = 65L) # no label attr
  out <- op_attr_mismatch(
    dm,
    .ctx(DM = dm, ADSL = adsl),
    name = "AGE",
    attribute = "label",
    reference_dataset = "ADSL"
  )
  expect_true(all(is.na(out)))
})

test_that("op_attr_mismatch returns NA when reference dataset missing", {
  dm <- .with_label(data.frame(AGE = 65L), "AGE", "Age")
  out <- op_attr_mismatch(
    dm,
    .ctx(DM = dm),
    name = "AGE",
    attribute = "label",
    reference_dataset = "ADSL"
  )
  expect_true(all(is.na(out)))
})

test_that("op_attr_mismatch resolves friendly attribute names", {
  dm <- data.frame(AGE = 65L)
  attr(dm$AGE, "format.sas") <- "8."
  adsl <- data.frame(AGE = 65L)
  attr(adsl$AGE, "format.sas") <- "Z8."
  out <- op_attr_mismatch(
    dm,
    .ctx(DM = dm, ADSL = adsl),
    name = "AGE",
    attribute = "format",
    reference_dataset = "ADSL"
  )
  expect_true(isTRUE(out[[1L]]))
})

# =============================================================================
# op_shared_attr_mismatch
# =============================================================================

test_that("op_shared_attr_mismatch fires when any shared column differs", {
  dm <- .with_label(data.frame(USUBJID = "S1", AGE = 65L), "AGE", "Age Y")
  adsl <- .with_label(
    data.frame(USUBJID = "S1", AGE = 65L),
    "AGE",
    "Age at Screening"
  )
  adsl <- .with_label(adsl, "USUBJID", "Unique Subject Identifier")
  dm <- .with_label(dm, "USUBJID", "Unique Subject Identifier")
  out <- op_shared_attr_mismatch(
    dm,
    .ctx(DM = dm, ADSL = adsl),
    attribute = "label",
    reference_dataset = "ADSL"
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("op_shared_attr_mismatch silent when all shared labels match", {
  dm <- .with_label(data.frame(USUBJID = "S1"), "USUBJID", "USUBJID label")
  adsl <- .with_label(data.frame(USUBJID = "S1"), "USUBJID", "USUBJID label")
  out <- op_shared_attr_mismatch(
    dm,
    .ctx(DM = dm, ADSL = adsl),
    attribute = "label",
    reference_dataset = "ADSL"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_shared_attr_mismatch respects exclude", {
  dm <- .with_label(data.frame(USUBJID = "S1", AGE = 65L), "AGE", "Age DM")
  adsl <- .with_label(data.frame(USUBJID = "S1", AGE = 65L), "AGE", "Age ADSL")
  out <- op_shared_attr_mismatch(
    dm,
    .ctx(DM = dm, ADSL = adsl),
    attribute = "label",
    reference_dataset = "ADSL",
    exclude = "AGE"
  )
  expect_false(isTRUE(out[[1L]]))
})

# =============================================================================
# op_dataset_label_not
# =============================================================================

test_that("op_dataset_label_not fires on label mismatch", {
  adsl <- data.frame(USUBJID = "S1")
  attr(adsl, "label") <- "Wrong Label"
  out <- op_dataset_label_not(
    adsl,
    list(),
    expected = "Subject-Level Analysis Dataset"
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("op_dataset_label_not passes when labels match (trimmed, CI)", {
  adsl <- data.frame(USUBJID = "S1")
  attr(adsl, "label") <- " subject-level analysis dataset "
  out <- op_dataset_label_not(
    adsl,
    list(),
    expected = "Subject-Level Analysis Dataset"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("op_dataset_label_not returns NA when label attr missing", {
  adsl <- data.frame(USUBJID = "S1")
  out <- op_dataset_label_not(adsl, list(), expected = "X")
  expect_true(all(is.na(out)))
})

# =============================================================================
# op_treatment_var_absent_across_datasets
# =============================================================================

test_that("treatment-absent fires when both sides lack treatment vars", {
  adae <- data.frame(USUBJID = "S1", AEDECOD = "X", stringsAsFactors = FALSE)
  adsl <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  out <- op_treatment_var_absent_across_datasets(
    adae,
    .ctx(ADAE = adae, ADSL = adsl),
    current_vars = list("TRTP", "TRTA"),
    reference_vars = list("TRTxxP", "TRTxxA"),
    reference_dataset = "ADSL"
  )
  expect_true(isTRUE(out[[1L]]))
})

test_that("treatment-absent passes when current dataset has TRTP", {
  adae <- data.frame(USUBJID = "S1", TRTP = "PLAC", stringsAsFactors = FALSE)
  adsl <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  out <- op_treatment_var_absent_across_datasets(
    adae,
    .ctx(ADAE = adae, ADSL = adsl),
    current_vars = list("TRTP", "TRTA"),
    reference_vars = list("TRTxxP")
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("treatment-absent passes when ADSL has TRT01P", {
  adae <- data.frame(USUBJID = "S1", AEDECOD = "X", stringsAsFactors = FALSE)
  adsl <- data.frame(USUBJID = "S1", TRT01P = "PLAC", stringsAsFactors = FALSE)
  out <- op_treatment_var_absent_across_datasets(
    adae,
    .ctx(ADAE = adae, ADSL = adsl),
    current_vars = list("TRTP"),
    reference_vars = list("TRTxxP")
  )
  expect_false(isTRUE(out[[1L]]))
})

# =============================================================================
# op_value_not_in_subject_indexed_set
# =============================================================================

test_that("value-not-in-set fires when row value absent from subject set", {
  adsl <- data.frame(
    USUBJID = c("S1", "S2"),
    TRT01P = c("PLAC", "DRUG"),
    TRT02P = c("DRUG", NA),
    stringsAsFactors = FALSE
  )
  adae <- data.frame(
    USUBJID = c("S1", "S1", "S2"),
    TRTP = c("PLAC", "DRUG", "OTHER"),
    stringsAsFactors = FALSE
  )
  out <- op_value_not_in_subject_indexed_set(
    adae,
    .ctx(ADSL = adsl, ADAE = adae),
    name = "TRTP",
    reference_dataset = "ADSL",
    reference_template = "TRTxxP"
  )
  expect_equal(out, c(FALSE, FALSE, TRUE))
})

test_that("value-not-in-set returns NA when subject not in reference", {
  adsl <- data.frame(USUBJID = "S1", TRT01P = "PLAC", stringsAsFactors = FALSE)
  adae <- data.frame(USUBJID = "S9", TRTP = "X", stringsAsFactors = FALSE)
  out <- op_value_not_in_subject_indexed_set(
    adae,
    .ctx(ADSL = adsl, ADAE = adae),
    name = "TRTP",
    reference_dataset = "ADSL",
    reference_template = "TRTxxP"
  )
  expect_true(all(is.na(out)))
})

test_that("value-not-in-set returns NA when template matches no columns", {
  adsl <- data.frame(USUBJID = "S1", FOO = "X", stringsAsFactors = FALSE)
  adae <- data.frame(USUBJID = "S1", TRTP = "X", stringsAsFactors = FALSE)
  out <- op_value_not_in_subject_indexed_set(
    adae,
    .ctx(ADSL = adsl, ADAE = adae),
    name = "TRTP",
    reference_dataset = "ADSL",
    reference_template = "TRTxxP"
  )
  expect_true(all(is.na(out)))
})

test_that("value-not-in-set honours compound templates (PxxSw)", {
  adsl <- data.frame(
    USUBJID = "S1",
    P01S1 = "A",
    P01S2 = "B",
    P02S1 = "C",
    stringsAsFactors = FALSE
  )
  cur <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    ASPER = c("A", "C", "Z"),
    stringsAsFactors = FALSE
  )
  out <- op_value_not_in_subject_indexed_set(
    cur,
    .ctx(ADSL = adsl, CUR = cur),
    name = "ASPER",
    reference_dataset = "ADSL",
    reference_template = "PxxSw"
  )
  expect_equal(out, c(FALSE, FALSE, TRUE))
})

# =============================================================================
# op_shared_values_mismatch_by_key
# =============================================================================

test_that("shared_values_mismatch_by_key fires on per-row value mismatch", {
  adsl <- data.frame(
    USUBJID = c("S1", "S2"),
    AGE = c(65L, 72L),
    SEX = c("M", "F"),
    stringsAsFactors = FALSE
  )
  cur <- data.frame(
    USUBJID = c("S1", "S2", "S2"),
    AGE = c(65L, 72L, 80L),
    SEX = c("M", "F", "F"),
    stringsAsFactors = FALSE
  )
  out <- op_shared_values_mismatch_by_key(
    cur,
    .ctx(ADSL = adsl, CUR = cur),
    reference_dataset = "ADSL"
  )
  expect_equal(out, c(FALSE, FALSE, TRUE))
})

test_that("shared_values_mismatch_by_key returns NA when subject absent in ref", {
  adsl <- data.frame(USUBJID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  cur <- data.frame(USUBJID = "S9", AGE = 90L, stringsAsFactors = FALSE)
  out <- op_shared_values_mismatch_by_key(
    cur,
    .ctx(ADSL = adsl, CUR = cur),
    reference_dataset = "ADSL"
  )
  expect_true(all(is.na(out)))
})

test_that("shared_values_mismatch_by_key honours exclude list", {
  adsl <- data.frame(
    USUBJID = "S1",
    AGE = 65L,
    SEX = "M",
    stringsAsFactors = FALSE
  )
  cur <- data.frame(
    USUBJID = "S1",
    AGE = 99L,
    SEX = "M",
    stringsAsFactors = FALSE
  )
  out <- op_shared_values_mismatch_by_key(
    cur,
    .ctx(ADSL = adsl, CUR = cur),
    reference_dataset = "ADSL",
    exclude = "AGE"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("shared_values_mismatch_by_key compares R Date vs ISO string", {
  adsl <- data.frame(
    USUBJID = "S1",
    RFSTDTC = "2024-01-01",
    stringsAsFactors = FALSE
  )
  cur <- data.frame(
    USUBJID = "S1",
    RFSTDTC = as.Date("2024-01-01"),
    stringsAsFactors = FALSE
  )
  out <- op_shared_values_mismatch_by_key(
    cur,
    .ctx(ADSL = adsl, CUR = cur),
    reference_dataset = "ADSL"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("shared_values_mismatch_by_key normalises numeric representations", {
  adsl <- data.frame(USUBJID = "S1", AGE = 65, stringsAsFactors = FALSE)
  cur <- data.frame(USUBJID = "S1", AGE = "65.0", stringsAsFactors = FALSE)
  out <- op_shared_values_mismatch_by_key(
    cur,
    .ctx(ADSL = adsl, CUR = cur),
    reference_dataset = "ADSL"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("shared_values_mismatch_by_key treats both-null as equal (P21 NULL==NULL)", {
  adsl <- data.frame(
    USUBJID = "S1",
    AGE = NA_integer_,
    stringsAsFactors = FALSE
  )
  cur <- data.frame(USUBJID = "S1", AGE = NA_integer_, stringsAsFactors = FALSE)
  out <- op_shared_values_mismatch_by_key(
    cur,
    .ctx(ADSL = adsl, CUR = cur),
    reference_dataset = "ADSL"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("shared_values_mismatch_by_key fires when one side is null in ref", {
  adsl <- data.frame(
    USUBJID = "S1",
    AGE = NA_integer_,
    stringsAsFactors = FALSE
  )
  cur <- data.frame(USUBJID = "S1", AGE = 65L, stringsAsFactors = FALSE)
  out <- op_shared_values_mismatch_by_key(
    cur,
    .ctx(ADSL = adsl, CUR = cur),
    reference_dataset = "ADSL"
  )
  expect_true(isTRUE(out[[1L]]))
})

# =============================================================================
# op_not_equal_subject_templated_ref
# =============================================================================

test_that("not_equal_subject_templated_ref fires per-row datetime mismatch", {
  adsl <- data.frame(
    USUBJID = "S1",
    P01S1SDM = "2024-01-01",
    P01S2SDM = "2024-03-01",
    stringsAsFactors = FALSE
  )
  bds <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    APERIOD = c(1L, 1L, 1L),
    ASPER = c(1L, 2L, 2L),
    ASPRSDTM = c("2024-01-01", "2024-03-01", "WRONG"),
    stringsAsFactors = FALSE
  )
  out <- op_not_equal_subject_templated_ref(
    bds,
    .ctx(ADSL = adsl, BDS = bds),
    name = "ASPRSDTM",
    reference_dataset = "ADSL",
    reference_template = "PxxSwSDM",
    index_cols = list(xx = "APERIOD", w = "ASPER")
  )
  expect_equal(out, c(FALSE, FALSE, TRUE))
})

test_that("not_equal_subject_templated_ref returns NA when resolved column absent", {
  adsl <- data.frame(
    USUBJID = "S1",
    P01S1SDM = "2024-01-01",
    stringsAsFactors = FALSE
  )
  bds <- data.frame(
    USUBJID = "S1",
    APERIOD = 2L,
    ASPER = 1L,
    ASPRSDTM = "2024-05-01",
    stringsAsFactors = FALSE
  )
  out <- op_not_equal_subject_templated_ref(
    bds,
    .ctx(ADSL = adsl, BDS = bds),
    name = "ASPRSDTM",
    reference_dataset = "ADSL",
    reference_template = "PxxSwSDM",
    index_cols = list(xx = "APERIOD", w = "ASPER")
  )
  expect_true(all(is.na(out)))
})

test_that("ASPRSDTM compares cleanly when XPT ingest gave POSIXct and JSON gave ISO", {
  adsl <- data.frame(
    USUBJID = "S1",
    P01S1SDM = "2024-01-01T00:00:00",
    stringsAsFactors = FALSE
  )
  bds <- data.frame(
    USUBJID = "S1",
    APERIOD = 1L,
    ASPER = 1L,
    ASPRSDTM = as.POSIXct("2024-01-01 00:00:00", tz = "UTC"),
    stringsAsFactors = FALSE
  )
  out <- op_not_equal_subject_templated_ref(
    bds,
    .ctx(ADSL = adsl, BDS = bds),
    name = "ASPRSDTM",
    reference_dataset = "ADSL",
    reference_template = "PxxSwSDM",
    index_cols = list(xx = "APERIOD", w = "ASPER")
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("ASPRSDTM treats datetime prefix equality as match (P21 fuzzy)", {
  adsl <- data.frame(
    USUBJID = "S1",
    P01S1SDM = "2024-01-01T00:00:00",
    stringsAsFactors = FALSE
  )
  bds <- data.frame(
    USUBJID = "S1",
    APERIOD = 1L,
    ASPER = 1L,
    ASPRSDTM = "2024-01-01",
    stringsAsFactors = FALSE
  )
  out <- op_not_equal_subject_templated_ref(
    bds,
    .ctx(ADSL = adsl, BDS = bds),
    name = "ASPRSDTM",
    reference_dataset = "ADSL",
    reference_template = "PxxSwSDM",
    index_cols = list(xx = "APERIOD", w = "ASPER")
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("not_equal_subject_templated_ref returns NA on NA index value", {
  adsl <- data.frame(
    USUBJID = "S1",
    P01S1SDM = "2024-01-01",
    stringsAsFactors = FALSE
  )
  bds <- data.frame(
    USUBJID = "S1",
    APERIOD = NA_integer_,
    ASPER = 1L,
    ASPRSDTM = "2024-01-01",
    stringsAsFactors = FALSE
  )
  out <- op_not_equal_subject_templated_ref(
    bds,
    .ctx(ADSL = adsl, BDS = bds),
    name = "ASPRSDTM",
    reference_dataset = "ADSL",
    reference_template = "PxxSwSDM",
    index_cols = list(xx = "APERIOD", w = "ASPER")
  )
  expect_true(all(is.na(out)))
})

# =============================================================================
# op_is_inconsistent_across_dataset
# =============================================================================

test_that("is_inconsistent_across_dataset", {
  dm <- data.frame(
    USUBJID = c("S1", "S2", "S3"),
    AGE = c(65, 72, 50),
    stringsAsFactors = FALSE
  )
  ae <- data.frame(
    USUBJID = c("S1", "S2", "S4"),
    AGE = c(65, 72, 40),
    stringsAsFactors = FALSE
  )
  ctx <- list(datasets = list(DM = dm, AE = ae))
  out <- op_is_inconsistent_across_dataset(
    ae,
    ctx,
    "AGE",
    list(reference_dataset = "DM", by = "USUBJID", column = "AGE")
  )
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

# =============================================================================
# op_has_next_corresponding_record / op_does_not_have_next_corresponding_record
# =============================================================================

test_that("has_next_corresponding_record / does_not_have...", {
  ae <- data.frame(USUBJID = c("S1", "S2", "S3"), stringsAsFactors = FALSE)
  suppae <- data.frame(USUBJID = c("S1", "S3"), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = ae, SUPPAE = suppae))

  missing_child <- op_does_not_have_next_corresponding_record(
    ae,
    ctx,
    "USUBJID",
    list(reference_dataset = "SUPPAE", by = "USUBJID")
  )
  expect_equal(missing_child, c(FALSE, TRUE, FALSE))

  has_child <- op_has_next_corresponding_record(
    ae,
    ctx,
    "USUBJID",
    list(reference_dataset = "SUPPAE", by = "USUBJID")
  )
  expect_equal(has_child, c(TRUE, FALSE, TRUE))
})

# =============================================================================
# op_differs_by_key / op_matches_by_key
# =============================================================================

test_that("differs_by_key fires where joined value diverges", {
  ae <- data.frame(
    VISITNUM = c(1, 2, 3),
    VISITDY = c(1, 8, 99),
    stringsAsFactors = FALSE
  )
  tv <- data.frame(
    VISITNUM = c(1, 2, 3),
    VISITDY = c(1, 8, 15),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(AE = ae, TV = tv))

  mask <- op_differs_by_key(
    ae,
    ctx,
    name = "VISITDY",
    reference_dataset = "TV",
    reference_column = "VISITDY",
    key = "VISITNUM"
  )
  expect_equal(mask, c(FALSE, FALSE, TRUE))
})

test_that("matches_by_key is the inverse of differs_by_key", {
  ae <- data.frame(
    VISITNUM = c(1, 2),
    VISITDY = c(1, 99),
    stringsAsFactors = FALSE
  )
  tv <- data.frame(
    VISITNUM = c(1, 2),
    VISITDY = c(1, 8),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(AE = ae, TV = tv))
  expect_equal(
    op_matches_by_key(
      ae,
      ctx,
      "VISITDY",
      reference_dataset = "TV",
      reference_column = "VISITDY",
      key = "VISITNUM"
    ),
    c(TRUE, FALSE)
  )
})

test_that("differs_by_key returns NA when the row's key has no match in ref", {
  ae <- data.frame(
    VISITNUM = c(1, 99),
    VISITDY = c(1, 1),
    stringsAsFactors = FALSE
  )
  tv <- data.frame(
    VISITNUM = c(1, 2),
    VISITDY = c(1, 8),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(AE = ae, TV = tv))
  mask <- op_differs_by_key(
    ae,
    ctx,
    "VISITDY",
    reference_dataset = "TV",
    reference_column = "VISITDY",
    key = "VISITNUM"
  )
  expect_equal(mask, c(FALSE, NA))
})

test_that("differs_by_key returns NA mask when the reference dataset is missing", {
  ae <- data.frame(
    VISITNUM = c(1, 2),
    VISITDY = c(1, 8),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(AE = ae))
  mask <- op_differs_by_key(
    ae,
    ctx,
    "VISITDY",
    reference_dataset = "TV",
    reference_column = "VISITDY",
    key = "VISITNUM"
  )
  expect_equal(mask, rep(NA, 2L))
})

test_that("differs_by_key accepts a distinct reference_key", {
  sv <- data.frame(
    VISITNUM = c(1, 2),
    VISITDY = c(1, 8),
    stringsAsFactors = FALSE
  )
  tv <- data.frame(
    VISITNO = c(1, 2),
    VISITDY = c(1, 8),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(SV = sv, TV = tv))
  mask <- op_differs_by_key(
    sv,
    ctx,
    "VISITDY",
    reference_dataset = "TV",
    reference_column = "VISITDY",
    key = "VISITNUM",
    reference_key = "VISITNO"
  )
  expect_equal(mask, c(FALSE, FALSE))
})

test_that("differs_by_key defaults key to `name` when omitted", {
  ae <- data.frame(
    USUBJID = c("S1", "S2"),
    SEX = c("M", "F"),
    stringsAsFactors = FALSE
  )
  dm <- data.frame(
    USUBJID = c("S1", "S2"),
    SEX = c("M", "M"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(AE = ae, DM = dm))
  mask <- op_differs_by_key(
    ae,
    ctx,
    "SEX",
    reference_dataset = "DM",
    reference_column = "SEX",
    key = "USUBJID"
  )
  expect_equal(mask, c(FALSE, TRUE))
})

test_that("both ops are discoverable via the op table", {
  expect_true("differs_by_key" %in% .list_ops())
  expect_true("matches_by_key" %in% .list_ops())
})

test_that("differs_by_key supports a composite (vector) key", {
  sv <- data.frame(
    USUBJID = c("S1", "S1", "S2"),
    ETCD = c("A", "B", "A"),
    EPOCH = c("TREATMENT", "FOLLOW-UP", "WRONG"),
    stringsAsFactors = FALSE
  )
  se <- data.frame(
    USUBJID = c("S1", "S1", "S2"),
    ETCD = c("A", "B", "A"),
    EPOCH = c("TREATMENT", "FOLLOW-UP", "TREATMENT"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(SV = sv, SE = se))
  mask <- herald:::op_differs_by_key(
    sv,
    ctx,
    name = "EPOCH",
    reference_dataset = "SE",
    reference_column = "EPOCH",
    key = c("USUBJID", "ETCD")
  )
  expect_equal(mask, c(FALSE, FALSE, TRUE))
})

test_that("differs_by_key NA when composite key col missing in data", {
  sv <- data.frame(
    USUBJID = c("S1"),
    EPOCH = c("TREATMENT"),
    stringsAsFactors = FALSE
  )
  se <- data.frame(
    USUBJID = c("S1"),
    ETCD = c("A"),
    EPOCH = c("TREATMENT"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(SV = sv, SE = se))
  mask <- herald:::op_differs_by_key(
    sv,
    ctx,
    name = "EPOCH",
    reference_dataset = "SE",
    reference_column = "EPOCH",
    key = c("USUBJID", "ETCD")
  )
  expect_equal(mask, NA)
})

# =============================================================================
# op_is_not_constant_per_group
# =============================================================================

test_that("is_not_constant_per_group fires all rows in a violating group", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR", "SBP", "SBP"),
    CRITTY1 = c("A", "B", "A", "X", "X"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d,
    ctx_empty,
    name = "CRITTY1",
    group_by = list("PARAMCD")
  )
  expect_equal(out, c(TRUE, TRUE, TRUE, FALSE, FALSE))
})

test_that("is_not_constant_per_group returns FALSE when all groups are constant", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "SBP"),
    CRITy = c("A", "A", "X"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d,
    ctx_empty,
    name = "CRITy",
    group_by = list("PARAMCD")
  )
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

test_that("is_not_constant_per_group ignores NA values in name column", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR"),
    BASETYPE = c(NA, NA, NA),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d,
    ctx_empty,
    name = "BASETYPE",
    group_by = list("PARAMCD")
  )
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

test_that("is_not_constant_per_group returns NA when name column absent", {
  d <- data.frame(PARAMCD = c("HR", "SBP"), stringsAsFactors = FALSE)
  out <- herald:::op_is_not_constant_per_group(
    d,
    ctx_empty,
    name = "MISSING_COL",
    group_by = list("PARAMCD")
  )
  expect_equal(out, c(NA, NA))
})

test_that("is_not_constant_per_group returns NA when group_by col absent", {
  d <- data.frame(
    CRITy = c("A", "B"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d,
    ctx_empty,
    name = "CRITy",
    group_by = list("PARAMCD")
  )
  expect_equal(out, c(NA, NA))
})

test_that("is_not_constant_per_group handles empty dataset", {
  d <- data.frame(
    PARAMCD = character(0L),
    CRITy = character(0L),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d,
    ctx_empty,
    name = "CRITy",
    group_by = list("PARAMCD")
  )
  expect_length(out, 0L)
})

test_that("is_not_constant_per_group works with composite group_by", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR", "HR"),
    BASETYPE = c("A", "B", "A", "A"),
    USUBJID = c("S1", "S1", "S2", "S2"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d,
    ctx_empty,
    name = "BASETYPE",
    group_by = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(TRUE, TRUE, FALSE, FALSE))
})

test_that("is_not_constant_per_group trims trailing whitespace before comparing", {
  d <- data.frame(
    PARAMCD = c("HR", "HR"),
    CRITy = c("High blood pressure", "High blood pressure  "),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_is_not_constant_per_group(
    d,
    ctx_empty,
    name = "CRITy",
    group_by = list("PARAMCD")
  )
  expect_equal(out, c(FALSE, FALSE))
})

# =============================================================================
# op_no_baseline_record
# =============================================================================

test_that("no_baseline_record fires when BASE populated but no ABLFL=Y", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR"),
    USUBJID = c("S1", "S1", "S1"),
    BASE = c(70, 70, NA),
    ABLFL = c(NA, NA, NA),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d,
    ctx_empty,
    name = "BASE",
    flag_var = "ABLFL",
    flag_value = "Y",
    group_by = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(TRUE, TRUE, TRUE))
})

test_that("no_baseline_record does not fire when ABLFL=Y present", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "HR"),
    USUBJID = c("S1", "S1", "S1"),
    BASE = c(70, 70, 70),
    ABLFL = c("Y", NA, NA),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d,
    ctx_empty,
    name = "BASE",
    flag_var = "ABLFL",
    flag_value = "Y",
    group_by = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

test_that("no_baseline_record does not fire when BASE not populated in group", {
  d <- data.frame(
    PARAMCD = c("HR", "HR"),
    USUBJID = c("S1", "S1"),
    BASE = c(NA, NA),
    ABLFL = c(NA, NA),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d,
    ctx_empty,
    name = "BASE",
    flag_var = "ABLFL",
    flag_value = "Y",
    group_by = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(FALSE, FALSE))
})

test_that("no_baseline_record returns NA when name column absent", {
  d <- data.frame(
    PARAMCD = c("HR"),
    ABLFL = c("Y"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d,
    ctx_empty,
    name = "BASE",
    flag_var = "ABLFL",
    flag_value = "Y",
    group_by = list("PARAMCD")
  )
  expect_equal(out, NA)
})

test_that("no_baseline_record returns NA when flag_var column absent", {
  d <- data.frame(
    PARAMCD = c("HR"),
    BASE = c(70),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d,
    ctx_empty,
    name = "BASE",
    flag_var = "ABLFL",
    flag_value = "Y",
    group_by = list("PARAMCD")
  )
  expect_equal(out, NA)
})

test_that("no_baseline_record handles multiple groups independently", {
  d <- data.frame(
    PARAMCD = c("HR", "HR", "SBP", "SBP"),
    USUBJID = c("S1", "S1", "S2", "S2"),
    BASE = c(70, 70, NA, NA),
    ABLFL = c(NA, NA, NA, NA),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d,
    ctx_empty,
    name = "BASE",
    flag_var = "ABLFL",
    flag_value = "Y",
    group_by = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(TRUE, TRUE, FALSE, FALSE))
})

test_that("no_baseline_record handles empty dataset", {
  d <- data.frame(
    PARAMCD = character(0L),
    USUBJID = character(0L),
    BASE = numeric(0L),
    ABLFL = character(0L),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d,
    ctx_empty,
    name = "BASE",
    flag_var = "ABLFL",
    flag_value = "Y",
    group_by = list("PARAMCD", "USUBJID")
  )
  expect_length(out, 0L)
})

test_that("no_baseline_record uses exact flag_value match (case-sensitive)", {
  d <- data.frame(
    PARAMCD = c("HR", "HR"),
    USUBJID = c("S1", "S1"),
    BASE = c(70, 70),
    ABLFL = c("y", NA),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_no_baseline_record(
    d,
    ctx_empty,
    name = "BASE",
    flag_var = "ABLFL",
    flag_value = "Y",
    group_by = list("PARAMCD", "USUBJID")
  )
  expect_equal(out, c(TRUE, TRUE))
})

# =============================================================================
# op_base_not_equal_abl_row
# =============================================================================

test_that("base_not_equal_abl_row fires when b_var differs from anchor a_var", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    PARAMCD = c("HR", "HR", "HR"),
    ABLFL = c("Y", NA, NA),
    AVAL = c(70, 75, 80),
    BASE = c(70, 75, 75),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d,
    ctx_empty,
    b_var = "BASE",
    a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"),
    basetype_gate = "any"
  )
  expect_true(out[[2L]])
  expect_true(out[[3L]])
  expect_false(isTRUE(out[[1L]]))
})

test_that("base_not_equal_abl_row passes when b_var matches anchor a_var", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    PARAMCD = c("HR", "HR"),
    ABLFL = c("Y", NA),
    AVAL = c(70, 70),
    BASE = c(70, 70),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d,
    ctx_empty,
    b_var = "BASE",
    a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"),
    basetype_gate = "any"
  )
  expect_true(all(!out))
})

test_that("base_not_equal_abl_row passes when b_var is not populated", {
  d <- data.frame(
    USUBJID = "S1",
    PARAMCD = "HR",
    ABLFL = "Y",
    AVAL = 70,
    BASE = NA_real_,
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d,
    ctx_empty,
    b_var = "BASE",
    a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"),
    basetype_gate = "any"
  )
  expect_false(isTRUE(out[[1L]]))
})

test_that("base_not_equal_abl_row returns NA when group has no anchor row", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    PARAMCD = c("HR", "HR"),
    ABLFL = c(NA, NA),
    AVAL = c(70, 75),
    BASE = c(70, 75),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d,
    ctx_empty,
    b_var = "BASE",
    a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"),
    basetype_gate = "any"
  )
  expect_true(all(is.na(out)))
})

test_that("base_not_equal_abl_row skips dataset when basetype_gate=absent and BASETYPE present", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    PARAMCD = c("HR", "HR"),
    ABLFL = c("Y", NA),
    AVAL = c(70, 70),
    BASE = c(70, 99),
    BASETYPE = c("Last", "Last"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d,
    ctx_empty,
    b_var = "BASE",
    a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"),
    basetype_gate = "absent"
  )
  expect_true(all(!out))
})

test_that("base_not_equal_abl_row runs when basetype_gate=absent and BASETYPE absent", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    PARAMCD = c("HR", "HR"),
    ABLFL = c("Y", NA),
    AVAL = c(70, 70),
    BASE = c(70, 99),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d,
    ctx_empty,
    b_var = "BASE",
    a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD"),
    basetype_gate = "absent"
  )
  expect_true(out[[2L]])
})

test_that("base_not_equal_abl_row skips null-BASETYPE rows when gate=populated", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    PARAMCD = c("HR", "HR", "HR"),
    ABLFL = c("Y", NA, NA),
    AVAL = c(70, 70, 70),
    BASE = c(70, 99, 99),
    BASETYPE = c(NA, NA, "Last"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d,
    ctx_empty,
    b_var = "BASE",
    a_var = "AVAL",
    group_by = list("USUBJID", "PARAMCD", "BASETYPE"),
    basetype_gate = "populated"
  )
  expect_false(isTRUE(out[[2L]]))
  expect_true(is.na(out[[3L]]))
})

test_that("base_not_equal_abl_row returns NA advisory for absent b_var column", {
  d <- data.frame(
    USUBJID = "S1",
    AVAL = 70,
    ABLFL = "Y",
    stringsAsFactors = FALSE
  )
  out <- herald:::op_base_not_equal_abl_row(
    d,
    ctx_empty,
    b_var = "BASE",
    a_var = "AVAL",
    group_by = list("USUBJID"),
    basetype_gate = "any"
  )
  expect_true(is.na(out[[1L]]))
})

# =============================================================================
# op_max_n_records_per_group_matching
# =============================================================================

test_that("max_n_records_per_group_matching fires all rows in violating group", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1", "S2"),
    DSSCAT = c(
      "STUDY PARTICIPATION",
      "STUDY PARTICIPATION",
      "OTHER",
      "STUDY PARTICIPATION"
    ),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_max_n_records_per_group_matching(
    d,
    ctx_empty,
    name = "DSSCAT",
    value = "STUDY PARTICIPATION",
    group_keys = "USUBJID",
    max_n = 1L
  )
  expect_true(out[[1L]])
  expect_true(out[[2L]])
  expect_true(out[[3L]])
  expect_false(out[[4L]])
})

test_that("max_n_records_per_group_matching does not fire when count equals max_n", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    FLAG = c("Y", "N"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_max_n_records_per_group_matching(
    d,
    ctx_empty,
    name = "FLAG",
    value = "Y",
    group_keys = "USUBJID",
    max_n = 1L
  )
  expect_equal(out, c(FALSE, FALSE))
})

test_that("max_n_records_per_group_matching returns NA when name column absent", {
  d <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  out <- herald:::op_max_n_records_per_group_matching(
    d,
    ctx_empty,
    name = "DSSCAT",
    value = "STUDY PARTICIPATION",
    group_keys = "USUBJID",
    max_n = 1L
  )
  expect_equal(out, c(NA, NA))
})

test_that("max_n_records_per_group_matching returns NA when group_keys col absent", {
  d <- data.frame(
    DSSCAT = c("STUDY PARTICIPATION", "OTHER"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_max_n_records_per_group_matching(
    d,
    ctx_empty,
    name = "DSSCAT",
    value = "STUDY PARTICIPATION",
    group_keys = "USUBJID",
    max_n = 1L
  )
  expect_equal(out, c(NA, NA))
})

test_that("max_n_records_per_group_matching handles empty dataset", {
  d <- data.frame(
    USUBJID = character(0L),
    DSSCAT = character(0L),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_max_n_records_per_group_matching(
    d,
    ctx_empty,
    name = "DSSCAT",
    value = "STUDY PARTICIPATION",
    group_keys = "USUBJID",
    max_n = 1L
  )
  expect_length(out, 0L)
})

test_that("max_n_records_per_group_matching works with composite group_keys", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1", "S1"),
    PARAMCD = c("HR", "HR", "SBP", "SBP"),
    ABLFL = c("Y", "Y", "Y", "N"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_max_n_records_per_group_matching(
    d,
    ctx_empty,
    name = "ABLFL",
    value = "Y",
    group_keys = c("USUBJID", "PARAMCD"),
    max_n = 1L
  )
  expect_true(out[[1L]])
  expect_true(out[[2L]])
  expect_false(out[[3L]])
  expect_false(out[[4L]])
})

test_that("max_n_records_per_group_matching trims trailing whitespace before match", {
  d <- data.frame(
    USUBJID = c("S1", "S1"),
    DSSCAT = c("STUDY PARTICIPATION  ", "STUDY PARTICIPATION"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_max_n_records_per_group_matching(
    d,
    ctx_empty,
    name = "DSSCAT",
    value = "STUDY PARTICIPATION",
    group_keys = "USUBJID",
    max_n = 1L
  )
  expect_true(all(out))
})

# =============================================================================
# op_next_row_not_equal
# =============================================================================

test_that("next_row_not_equal fires on row where name != next row prev_name", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    TAETORD = c(1L, 2L, 3L),
    SESTDTC = c("2024-01-01", "2024-01-03", "2024-01-07"),
    SEENDTC = c("2024-01-03", "2024-01-05", "2024-01-10"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(
      prev_name = "SESTDTC",
      order_by = "TAETORD",
      group_by = list("USUBJID")
    )
  )
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
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(
      prev_name = "SESTDTC",
      order_by = "TAETORD",
      group_by = list("USUBJID")
    )
  )
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

test_that("next_row_not_equal partitions by group_by independently", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S2", "S2"),
    TAETORD = c(1L, 2L, 1L, 2L),
    SESTDTC = c("2024-01-01", "2024-01-05", "2024-02-01", "2024-02-04"),
    SEENDTC = c("2024-01-05", "2024-01-10", "2024-02-04", "2024-02-10"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(
      prev_name = "SESTDTC",
      order_by = "TAETORD",
      group_by = list("USUBJID")
    )
  )
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
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(
      prev_name = "SESTDTC",
      order_by = "TAETORD",
      group_by = list("USUBJID")
    )
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
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(
      prev_name = "SESTDTC",
      order_by = "TAETORD",
      group_by = list("USUBJID")
    )
  )
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
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(
      prev_name = "SESTDTC",
      order_by = "TAETORD",
      group_by = list("USUBJID")
    )
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
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(
      prev_name = "SESTDTC",
      order_by = "TAETORD",
      group_by = list("USUBJID")
    )
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
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(
      prev_name = "SESTDTC",
      order_by = "TAETORD",
      group_by = list("USUBJID")
    )
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
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(
      prev_name = "SESTDTC",
      order_by = "TAETORD",
      group_by = list("USUBJID")
    )
  )
  expect_length(out, 0L)
})

test_that("next_row_not_equal respects order_by sort for unsorted input", {
  d <- data.frame(
    USUBJID = c("S1", "S1", "S1"),
    TAETORD = c(3L, 1L, 2L),
    SESTDTC = c("2024-01-07", "2024-01-01", "2024-01-04"),
    SEENDTC = c("2024-01-10", "2024-01-04", "2024-01-07"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_next_row_not_equal(
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(
      prev_name = "SESTDTC",
      order_by = "TAETORD",
      group_by = list("USUBJID")
    )
  )
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
    d,
    ctx_empty,
    name = "SEENDTC",
    value = list(prev_name = "SESTDTC", order_by = "TAETORD")
  )
  expect_equal(out, c(TRUE, FALSE))
})

# =============================================================================
# op_supp_row_count_exceeds
# =============================================================================

.count_fired_supp <- function(res, rule_id) {
  f <- res$findings[
    res$findings$rule_id == rule_id &
      res$findings$status == "fired",
    ,
    drop = FALSE
  ]
  nrow(f)
}

test_that("supp_row_count_exceeds fires when SUPP has >threshold matching QNAM rows", {
  dm <- data.frame(
    USUBJID = c("S1", "S2", "S3"),
    RACE = c("ASIAN", "WHITE", "MULTIPLE"),
    stringsAsFactors = FALSE
  )
  supp <- data.frame(
    USUBJID = c("S1", "S1", "S2", "S3", "S3"),
    RDOMAIN = rep("DM", 5L),
    QNAM = c("RACE1", "RACE2", "RACEOTH", "RACE1", "RACE2"),
    QLABEL = rep("Race", 5L),
    QVAL = c("ASIAN", "WHITE", "Other", "ASIAN", "WHITE"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm,
    ctx,
    ref_dataset = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold = 1L
  )
  expect_equal(mask, c(TRUE, FALSE, TRUE))
})

test_that("supp_row_count_exceeds returns FALSE at or below threshold", {
  dm <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  supp <- data.frame(
    USUBJID = c("S1", "S2"),
    QNAM = c("RACE1", "RACEOTH"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm,
    ctx,
    ref_dataset = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold = 1L
  )
  expect_equal(mask, c(FALSE, FALSE))
})

test_that("supp_row_count_exceeds returns NA when SUPP dataset is absent", {
  dm <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  ctx <- .mk_ctx_with(list(DM = dm))
  mask <- herald:::op_supp_row_count_exceeds(
    dm,
    ctx,
    ref_dataset = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold = 1L
  )
  expect_equal(mask, rep(NA, 2L))
})

test_that("supp_row_count_exceeds returns FALSE when QNAM pattern matches nothing", {
  dm <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  supp <- data.frame(
    USUBJID = c("S1", "S2"),
    QNAM = c("ETHNICITY", "SEXNOTE"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm,
    ctx,
    ref_dataset = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold = 1L
  )
  expect_equal(mask, c(FALSE, FALSE))
})

test_that("supp_row_count_exceeds returns FALSE when subject has no SUPP rows", {
  dm <- data.frame(
    USUBJID = c("S1", "S2", "S_MISSING"),
    stringsAsFactors = FALSE
  )
  supp <- data.frame(
    USUBJID = c("S1", "S1", "S2"),
    QNAM = c("RACE1", "RACE2", "RACE1"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm,
    ctx,
    ref_dataset = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold = 1L
  )
  expect_equal(mask, c(TRUE, FALSE, FALSE))
})

test_that("supp_row_count_exceeds honours a custom threshold", {
  dm <- data.frame(USUBJID = c("S1", "S2"), stringsAsFactors = FALSE)
  supp <- data.frame(
    USUBJID = c("S1", "S1", "S1", "S2", "S2"),
    QNAM = c("RACE1", "RACE2", "RACE3", "RACE1", "RACE2"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm,
    ctx,
    ref_dataset = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold = 2L
  )
  expect_equal(mask, c(TRUE, FALSE))
})

test_that("supp_row_count_exceeds returns NA when SUPP lacks QNAM column", {
  dm <- data.frame(USUBJID = c("S1"), stringsAsFactors = FALSE)
  supp <- data.frame(USUBJID = "S1", QVAL = "ASIAN", stringsAsFactors = FALSE)
  ctx <- .mk_ctx_with(list(DM = dm, SUPPDM = supp))
  mask <- herald:::op_supp_row_count_exceeds(
    dm,
    ctx,
    ref_dataset = "SUPPDM",
    qnam_pattern = "^RACE",
    threshold = 1L
  )
  expect_equal(mask, NA)
})

test_that("supp_row_count_exceeds is discoverable via the op registry", {
  expect_true("supp_row_count_exceeds" %in% herald:::.list_ops())
  meta <- herald:::.op_meta("supp_row_count_exceeds")
  expect_equal(meta$kind, "cross")
})

# ---------------------------------------------------------------------------
# Integration: CG0140 + CG0527
# ---------------------------------------------------------------------------

.dm_suppdm_fixture <- function() {
  dm <- data.frame(
    STUDYID = rep("STUDY", 4L),
    DOMAIN = rep("DM", 4L),
    USUBJID = c("S1", "S2", "S3", "S4"),
    RACE = c("ASIAN", "MULTIPLE", "WHITE", "ASIAN"),
    stringsAsFactors = FALSE
  )
  supp <- data.frame(
    STUDYID = rep("STUDY", 5L),
    RDOMAIN = rep("DM", 5L),
    USUBJID = c("S1", "S1", "S2", "S2", "S3"),
    IDVAR = rep("", 5L),
    IDVARVAL = rep("", 5L),
    QNAM = c("RACE1", "RACE2", "RACE1", "RACE2", "RACE1"),
    QLABEL = rep("Race", 5L),
    QVAL = c("ASIAN", "WHITE", "ASIAN", "BLACK", "WHITE"),
    QORIG = rep("CRF", 5L),
    QEVAL = rep("", 5L),
    stringsAsFactors = FALSE
  )
  list(DM = dm, SUPPDM = supp)
}

test_that("CG0140 fires only when DM.RACE != 'MULTIPLE' AND SUPPDM has >1 RACE rows", {
  fx <- .dm_suppdm_fixture()
  r <- herald::validate(files = fx, rules = "CG0140", quiet = TRUE)
  expect_equal(.count_fired_supp(r, "CG0140"), 1L)
})

test_that("CG0527 uses the same predicate as CG0140", {
  fx <- .dm_suppdm_fixture()
  r <- herald::validate(files = fx, rules = "CG0527", quiet = TRUE)
  expect_equal(.count_fired_supp(r, "CG0527"), 1L)
})

test_that("CG0140 emits no fire when SUPPDM dataset absent", {
  fx <- .dm_suppdm_fixture()
  r <- herald::validate(
    files = list(DM = fx$DM),
    rules = "CG0140",
    quiet = TRUE
  )
  expect_equal(.count_fired_supp(r, "CG0140"), 0L)
})

# =============================================================================
# op_study_metadata_is
# =============================================================================

test_that("op_study_metadata_is returns NA when study_metadata is NULL", {
  df <- data.frame(X = 1:3, stringsAsFactors = FALSE)
  ctx <- list(study_metadata = NULL)
  out <- herald:::op_study_metadata_is(
    df,
    ctx,
    key = "collected_domains",
    value = "MB"
  )
  expect_equal(out, rep(NA, 3L))
})

test_that("op_study_metadata_is returns NA when ctx is NULL", {
  df <- data.frame(X = 1:2, stringsAsFactors = FALSE)
  out <- herald:::op_study_metadata_is(
    df,
    NULL,
    key = "collected_domains",
    value = "MB"
  )
  expect_equal(out, rep(NA, 2L))
})

test_that("op_study_metadata_is returns TRUE when value is in collected_domains", {
  df <- data.frame(X = 1:2, stringsAsFactors = FALSE)
  ctx <- list(study_metadata = list(collected_domains = c("MB", "PC", "LB")))
  out <- herald:::op_study_metadata_is(
    df,
    ctx,
    key = "collected_domains",
    value = "MB"
  )
  expect_equal(out, rep(TRUE, 2L))
})

test_that("op_study_metadata_is returns FALSE when value is absent from collected_domains", {
  df <- data.frame(X = 1:2, stringsAsFactors = FALSE)
  ctx <- list(study_metadata = list(collected_domains = c("LB", "VS")))
  out <- herald:::op_study_metadata_is(
    df,
    ctx,
    key = "collected_domains",
    value = "MB"
  )
  expect_equal(out, rep(FALSE, 2L))
})

test_that("op_study_metadata_is is case-insensitive", {
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  ctx <- list(study_metadata = list(collected_domains = c("mb", "lB")))
  out <- herald:::op_study_metadata_is(
    df,
    ctx,
    key = "collected_domains",
    value = "MB"
  )
  expect_equal(out[[1L]], TRUE)
})

test_that("op_study_metadata_is returns FALSE when key is absent from study_metadata", {
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  ctx <- list(study_metadata = list(study_type = "Phase III"))
  out <- herald:::op_study_metadata_is(
    df,
    ctx,
    key = "collected_domains",
    value = "MB"
  )
  expect_equal(out, rep(FALSE, 1L))
})

test_that("op_study_metadata_is returns logical(0) for 0-row data", {
  df <- data.frame(X = integer(0), stringsAsFactors = FALSE)
  ctx <- list(study_metadata = list(collected_domains = c("MB")))
  out <- herald:::op_study_metadata_is(
    df,
    ctx,
    key = "collected_domains",
    value = "MB"
  )
  expect_equal(out, rep(TRUE, 0L))
})

# =============================================================================
# op_ref_column_domains_exist
# =============================================================================

test_that("op_ref_column_domains_exist fires when domain not in ctx$datasets", {
  relrec <- data.frame(RDOMAIN = c("DM", "XY"), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(DM = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(
    relrec,
    ctx,
    reference_column = "RDOMAIN"
  )
  expect_equal(out[[1L]], FALSE)
  expect_equal(out[[2L]], TRUE)
})

test_that("op_ref_column_domains_exist returns all FALSE when all domains present", {
  relrec <- data.frame(RDOMAIN = c("DM", "AE"), stringsAsFactors = FALSE)
  ctx <- list(
    datasets = list(
      DM = data.frame(USUBJID = "S1"),
      AE = data.frame(USUBJID = "S1")
    )
  )
  out <- herald:::op_ref_column_domains_exist(
    relrec,
    ctx,
    reference_column = "RDOMAIN"
  )
  expect_equal(any(out, na.rm = TRUE), FALSE)
})

test_that("op_ref_column_domains_exist returns NA for NA rows", {
  relrec <- data.frame(
    RDOMAIN = c("DM", NA_character_),
    stringsAsFactors = FALSE
  )
  ctx <- list(datasets = list(DM = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(
    relrec,
    ctx,
    reference_column = "RDOMAIN"
  )
  expect_equal(out[[1L]], FALSE)
  expect_true(is.na(out[[2L]]))
})

test_that("op_ref_column_domains_exist returns NA for empty-string rows", {
  relrec <- data.frame(RDOMAIN = c("AE", ""), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(
    relrec,
    ctx,
    reference_column = "RDOMAIN"
  )
  expect_equal(out[[1L]], FALSE)
  expect_true(is.na(out[[2L]]))
})

test_that("op_ref_column_domains_exist returns NA when column absent", {
  relrec <- data.frame(OTHER = "DM", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(DM = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(
    relrec,
    ctx,
    reference_column = "RDOMAIN"
  )
  expect_true(is.na(out[[1L]]))
})

test_that("op_ref_column_domains_exist is case-insensitive on domain names", {
  relrec <- data.frame(RDOMAIN = "dm", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(DM = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(
    relrec,
    ctx,
    reference_column = "RDOMAIN"
  )
  expect_equal(out[[1L]], FALSE)
})

test_that("op_ref_column_domains_exist returns logical(0) for 0-row data", {
  relrec <- data.frame(RDOMAIN = character(0), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(DM = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(
    relrec,
    ctx,
    reference_column = "RDOMAIN"
  )
  expect_equal(length(out), 0L)
})

# ---------------------------------------------------------------------------
# validate() integration for Q9 rules
# ---------------------------------------------------------------------------

test_that("CG0368: validate fires when DM is absent", {
  ae <- data.frame(
    USUBJID = "S1",
    AEDECOD = "HEADACHE",
    stringsAsFactors = FALSE
  )
  result <- validate(files = list(AE = ae), rules = "CG0368", quiet = TRUE)
  expect_gt(nrow(result$findings), 0L)
  expect_equal(result$findings$rule_id[[1L]], "CG0368")
})

test_that("CG0368: validate passes when DM is present", {
  dm <- data.frame(USUBJID = "S1", STUDYID = "STUDY1", stringsAsFactors = FALSE)
  result <- validate(files = list(DM = dm), rules = "CG0368", quiet = TRUE)
  expect_equal(nrow(result$findings), 0L)
})

test_that("CG0646: validate fires when SJ dataset is present", {
  sj <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(files = list(SJ = sj), rules = "CG0646", quiet = TRUE)
  expect_gt(nrow(result$findings), 0L)
  expect_equal(result$findings$rule_id[[1L]], "CG0646")
})

test_that("CG0646: validate passes when SJ dataset is absent", {
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(files = list(DM = dm), rules = "CG0646", quiet = TRUE)
  expect_equal(nrow(result$findings), 0L)
})

test_that("CG0191: validate is advisory when study_metadata is NULL", {
  ae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(files = list(AE = ae), rules = "CG0191", quiet = TRUE)
  expect_equal(nrow(result$findings), 0L)
})

test_that("CG0191: validate fires when MB collected but absent", {
  ae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(
    files = list(AE = ae),
    rules = "CG0191",
    study_metadata = list(collected_domains = c("MB", "LB")),
    quiet = TRUE
  )
  expect_gt(nrow(result$findings), 0L)
  expect_equal(result$findings$rule_id[[1L]], "CG0191")
})

test_that("CG0191: validate passes when MB collected and present", {
  mb <- data.frame(USUBJID = "S1", MBORRES = "E.COLI", stringsAsFactors = FALSE)
  result <- validate(
    files = list(MB = mb),
    rules = "CG0191",
    study_metadata = list(collected_domains = c("MB")),
    quiet = TRUE
  )
  expect_equal(nrow(result$findings), 0L)
})

test_that("CG0374: validate fires when RELREC references absent domain", {
  relrec <- data.frame(
    USUBJID = c("S1", "S1"),
    RDOMAIN = c("DM", "XY"),
    stringsAsFactors = FALSE
  )
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(
    files = list(RELREC = relrec, DM = dm),
    rules = "CG0374",
    quiet = TRUE
  )
  expect_gt(nrow(result$findings), 0L)
  expect_equal(result$findings$rule_id[[1L]], "CG0374")
})

test_that("CG0374: validate passes when all RELREC domains present", {
  relrec <- data.frame(
    USUBJID = c("S1", "S1"),
    RDOMAIN = c("DM", "AE"),
    stringsAsFactors = FALSE
  )
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  ae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(
    files = list(RELREC = relrec, DM = dm, AE = ae),
    rules = "CG0374",
    quiet = TRUE
  )
  expect_equal(nrow(result$findings), 0L)
})
