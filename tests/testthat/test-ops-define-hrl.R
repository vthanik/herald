# Tests for R/ops-define-hrl.R

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

.mk_vm <- function(variable, data_type, assigned_value = "", length = "200",
                   codelist_oid = "") {
  data.frame(
    variable = variable,
    data_type = data_type,
    assigned_value = assigned_value,
    length = length,
    codelist_oid = codelist_oid,
    stringsAsFactors = FALSE
  )
}

.mk_ctx_with <- function(datasets) {
  ctx <- herald:::new_herald_ctx()
  # .ref_ds() uses toupper() on the name, so keys must be UPPER case.
  names(datasets) <- toupper(names(datasets))
  ctx$datasets <- datasets
  ctx
}

# =============================================================================
# op_iso8601_data_type_match
# =============================================================================

test_that("iso8601_data_type_match fires for --DTC variable with dtype=text", {
  d <- .mk_vm(c("AESTDTC", "AEDECOD"), c("text", "text"))
  out <- herald:::op_iso8601_data_type_match(d, list())
  expect_equal(out, c(TRUE, FALSE))
})

test_that("iso8601_data_type_match fires for --DUR variable with dtype=text", {
  d <- .mk_vm(c("EXDUR", "EXDOSE"), c("text", "float"))
  out <- herald:::op_iso8601_data_type_match(d, list())
  expect_equal(out, c(TRUE, FALSE))
})

test_that("iso8601_data_type_match does not fire for --DTC with non-text dtype", {
  d <- .mk_vm(c("AESTDTC"), c("datetime"))
  out <- herald:::op_iso8601_data_type_match(d, list())
  expect_false(out[[1L]])
})

test_that("iso8601_data_type_match does not fire for NA dtype", {
  d <- .mk_vm(c("AESTDTC"), c(NA_character_))
  out <- herald:::op_iso8601_data_type_match(d, list())
  expect_false(out[[1L]])
})

test_that("iso8601_data_type_match handles empty dataset", {
  d <- data.frame(
    variable = character(0),
    data_type = character(0),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_iso8601_data_type_match(d, list())
  expect_length(out, 0L)
})

# =============================================================================
# op_define_version_matches_schema
# =============================================================================

test_that("define_version_matches_schema fires for invalid version", {
  d <- data.frame(def_version = c("2.0.0", "1.0.0", "2.1.0", "3.0.0"),
                  stringsAsFactors = FALSE)
  out <- herald:::op_define_version_matches_schema(d, list())
  expect_equal(out, c(FALSE, TRUE, FALSE, TRUE))
})

test_that("define_version_matches_schema does not fire for NA version", {
  d <- data.frame(def_version = NA_character_, stringsAsFactors = FALSE)
  out <- herald:::op_define_version_matches_schema(d, list())
  expect_false(out[[1L]])
})

test_that("define_version_matches_schema handles single valid version", {
  d <- data.frame(def_version = "2.1.0", stringsAsFactors = FALSE)
  out <- herald:::op_define_version_matches_schema(d, list())
  expect_false(out[[1L]])
})

# =============================================================================
# op_assigned_value_matches_data_type
# =============================================================================

test_that("assigned_value_matches_data_type fires for non-numeric assigned to integer type", {
  d <- .mk_vm(
    c("AESEQ", "AEDECOD"),
    c("integer", "text"),
    c("abc", "HEADACHE")
  )
  out <- herald:::op_assigned_value_matches_data_type(d, list())
  expect_true(out[[1L]])
  expect_false(out[[2L]])
})

test_that("assigned_value_matches_data_type passes for valid numeric value", {
  d <- .mk_vm("AESEQ", "integer", "1")
  out <- herald:::op_assigned_value_matches_data_type(d, list())
  expect_false(out[[1L]])
})

test_that("assigned_value_matches_data_type fires for non-ISO datetime value", {
  d <- .mk_vm("AESTDTC", "datetime", "not-a-date")
  out <- herald:::op_assigned_value_matches_data_type(d, list())
  expect_true(out[[1L]])
})

test_that("assigned_value_matches_data_type passes for valid ISO-like datetime value", {
  d <- .mk_vm("AESTDTC", "datetime", "2024-01-01")
  out <- herald:::op_assigned_value_matches_data_type(d, list())
  expect_false(out[[1L]])
})

test_that("assigned_value_matches_data_type passes when no assigned value", {
  d <- .mk_vm("AESEQ", "integer", "")
  out <- herald:::op_assigned_value_matches_data_type(d, list())
  expect_false(out[[1L]])
})

test_that("assigned_value_matches_data_type passes for duration datetime starting with P", {
  d <- .mk_vm("EXDUR", "durationDatetime", "P28D")
  out <- herald:::op_assigned_value_matches_data_type(d, list())
  expect_false(out[[1L]])
})

# =============================================================================
# op_assigned_value_length_le_var_length
# =============================================================================

test_that("assigned_value_length_le_var_length fires when value exceeds length", {
  d <- .mk_vm("AEDECOD", "text", "HEADACHE IS A VERY LONG TERM INDEED", "10")
  out <- herald:::op_assigned_value_length_le_var_length(d, list())
  expect_true(out[[1L]])
})

test_that("assigned_value_length_le_var_length passes when value within length", {
  d <- .mk_vm("AEDECOD", "text", "HEAD", "10")
  out <- herald:::op_assigned_value_length_le_var_length(d, list())
  expect_false(out[[1L]])
})

test_that("assigned_value_length_le_var_length passes when no assigned value", {
  d <- .mk_vm("AEDECOD", "text", "", "10")
  out <- herald:::op_assigned_value_length_le_var_length(d, list())
  expect_false(out[[1L]])
})

test_that("assigned_value_length_le_var_length passes when length is NA", {
  d <- .mk_vm("AEDECOD", "text", "HEADACHE", NA_character_)
  out <- herald:::op_assigned_value_length_le_var_length(d, list())
  expect_false(out[[1L]])
})

# =============================================================================
# op_valid_codelist_term
# =============================================================================

test_that("valid_codelist_term fires when assigned value not in codelist", {
  cl_meta <- data.frame(
    codelist_oid = c("CL.SEX", "CL.SEX"),
    coded_value = c("M", "F"),
    stringsAsFactors = FALSE
  )
  d <- data.frame(
    assigned_value = c("M", "UNKNOWN", ""),
    codelist_oid = c("CL.SEX", "CL.SEX", "CL.SEX"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(Define_Codelist_Metadata = cl_meta))
  out <- herald:::op_valid_codelist_term(d, ctx)
  expect_false(out[[1L]])
  expect_true(out[[2L]])
  expect_false(out[[3L]])
})

test_that("valid_codelist_term passes when no codelist_oid", {
  cl_meta <- data.frame(
    codelist_oid = "CL.SEX",
    coded_value = "M",
    stringsAsFactors = FALSE
  )
  d <- data.frame(
    assigned_value = "M",
    codelist_oid = "",
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(Define_Codelist_Metadata = cl_meta))
  out <- herald:::op_valid_codelist_term(d, ctx)
  expect_false(out[[1L]])
})

test_that("valid_codelist_term returns NA when Define_Codelist_Metadata absent", {
  d <- data.frame(
    assigned_value = "M",
    codelist_oid = "CL.SEX",
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list())
  out <- herald:::op_valid_codelist_term(d, ctx)
  expect_true(is.na(out[[1L]]))
})

# =============================================================================
# op_where_clause_value_in_codelist
# =============================================================================

test_that("where_clause_value_in_codelist fires when check value not in codelist", {
  var_meta <- data.frame(
    oid = "IT.AE.AESEV",
    codelist_oid = "CL.SEV",
    stringsAsFactors = FALSE
  )
  cl_meta <- data.frame(
    codelist_oid = c("CL.SEV", "CL.SEV", "CL.SEV"),
    coded_value = c("MILD", "MODERATE", "SEVERE"),
    stringsAsFactors = FALSE
  )
  d <- data.frame(
    check_value = c("MILD", "EXTREME"),
    check_var = c("IT.AE.AESEV", "IT.AE.AESEV"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(
    Define_Variable_Metadata = var_meta,
    Define_Codelist_Metadata = cl_meta
  ))
  out <- herald:::op_where_clause_value_in_codelist(d, ctx)
  expect_false(out[[1L]])
  expect_true(out[[2L]])
})

test_that("where_clause_value_in_codelist returns NA when var_meta absent", {
  d <- data.frame(
    check_value = "MILD",
    check_var = "IT.AE.AESEV",
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list())
  out <- herald:::op_where_clause_value_in_codelist(d, ctx)
  expect_true(is.na(out[[1L]]))
})

test_that("where_clause_value_in_codelist returns NA when check_var not in var_meta", {
  var_meta <- data.frame(
    oid = "IT.AE.AEDECOD",
    codelist_oid = "CL.DECOD",
    stringsAsFactors = FALSE
  )
  cl_meta <- data.frame(
    codelist_oid = "CL.DECOD",
    coded_value = "HEADACHE",
    stringsAsFactors = FALSE
  )
  d <- data.frame(
    check_value = "MILD",
    check_var = "IT.AE.AESEV",
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(
    Define_Variable_Metadata = var_meta,
    Define_Codelist_Metadata = cl_meta
  ))
  out <- herald:::op_where_clause_value_in_codelist(d, ctx)
  expect_true(is.na(out[[1L]]))
})

test_that("where_clause_value_in_codelist returns NA when no codelist for var", {
  var_meta <- data.frame(
    oid = "IT.AE.AESEV",
    codelist_oid = "",
    stringsAsFactors = FALSE
  )
  cl_meta <- data.frame(
    codelist_oid = "CL.SEV",
    coded_value = "MILD",
    stringsAsFactors = FALSE
  )
  d <- data.frame(
    check_value = "MILD",
    check_var = "IT.AE.AESEV",
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(
    Define_Variable_Metadata = var_meta,
    Define_Codelist_Metadata = cl_meta
  ))
  out <- herald:::op_where_clause_value_in_codelist(d, ctx)
  expect_true(is.na(out[[1L]]))
})

# =============================================================================
# op_arm_absent_in_non_adam_define
# =============================================================================

test_that("arm_absent_in_non_adam_define fires when study is not ADaM", {
  study_meta <- data.frame(is_adam = FALSE, stringsAsFactors = FALSE)
  d <- data.frame(
    display_oid = c("D01", "D02"),
    stringsAsFactors = FALSE
  )
  ctx <- .mk_ctx_with(list(Define_Study_Metadata = study_meta))
  out <- herald:::op_arm_absent_in_non_adam_define(d, ctx)
  expect_equal(out, c(TRUE, TRUE))
})

test_that("arm_absent_in_non_adam_define does not fire for ADaM define", {
  study_meta <- data.frame(is_adam = TRUE, stringsAsFactors = FALSE)
  d <- data.frame(display_oid = "D01", stringsAsFactors = FALSE)
  ctx <- .mk_ctx_with(list(Define_Study_Metadata = study_meta))
  out <- herald:::op_arm_absent_in_non_adam_define(d, ctx)
  expect_false(out[[1L]])
})

test_that("arm_absent_in_non_adam_define does not fire when study_meta absent", {
  d <- data.frame(display_oid = c("D01", "D02"), stringsAsFactors = FALSE)
  ctx <- .mk_ctx_with(list())
  out <- herald:::op_arm_absent_in_non_adam_define(d, ctx)
  expect_equal(out, c(FALSE, FALSE))
})

test_that("arm_absent_in_non_adam_define does not fire when study_meta is empty", {
  d <- data.frame(display_oid = "D01", stringsAsFactors = FALSE)
  study_meta <- data.frame(is_adam = logical(0), stringsAsFactors = FALSE)
  ctx <- .mk_ctx_with(list(Define_Study_Metadata = study_meta))
  out <- herald:::op_arm_absent_in_non_adam_define(d, ctx)
  expect_equal(out, FALSE)
})

# =============================================================================
# op_arm_oid_unique
# =============================================================================

test_that("arm_oid_unique fires on duplicate display_oid", {
  d <- data.frame(
    display_oid = c("D01", "D01", "D02"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_arm_oid_unique(d, list())
  expect_equal(out, c(TRUE, TRUE, FALSE))
})

test_that("arm_oid_unique passes when all OIDs are unique", {
  d <- data.frame(
    display_oid = c("D01", "D02", "D03"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_arm_oid_unique(d, list())
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

# =============================================================================
# op_arm_name_unique
# =============================================================================

test_that("arm_name_unique fires on duplicate display_name", {
  d <- data.frame(
    display_name = c("Table 1", "Table 1", "Figure 1"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_arm_name_unique(d, list())
  expect_equal(out, c(TRUE, TRUE, FALSE))
})

test_that("arm_name_unique passes when all names are unique", {
  d <- data.frame(
    display_name = c("Table 1", "Table 2"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_arm_name_unique(d, list())
  expect_equal(out, c(FALSE, FALSE))
})

# =============================================================================
# op_arm_description_required
# =============================================================================

test_that("arm_description_required fires when has_description is FALSE", {
  d <- data.frame(
    has_description = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_arm_description_required(d, list())
  expect_equal(out, c(FALSE, TRUE, FALSE))
})

# =============================================================================
# op_arm_analysisresult_oid_unique
# =============================================================================

test_that("arm_analysisresult_oid_unique fires when result_oid duplicated within display", {
  d <- data.frame(
    display_oid = c("D01", "D01", "D01", "D02"),
    result_oid = c("R01", "R01", "R02", "R01"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_arm_analysisresult_oid_unique(d, list())
  expect_equal(out, c(TRUE, TRUE, FALSE, FALSE))
})

test_that("arm_analysisresult_oid_unique passes when all result_oids unique per display", {
  d <- data.frame(
    display_oid = c("D01", "D01", "D02"),
    result_oid = c("R01", "R02", "R01"),
    stringsAsFactors = FALSE
  )
  out <- herald:::op_arm_analysisresult_oid_unique(d, list())
  expect_equal(out, c(FALSE, FALSE, FALSE))
})

# =============================================================================
# op_key_not_unique_per_define
# =============================================================================

test_that("key_not_unique_per_define fires when duplicate composite key", {
  ae <- data.frame(
    USUBJID = c("S1", "S1", "S2"),
    AESEQ = c(1L, 1L, 1L),
    AEDECOD = c("HEADACHE", "HEADACHE", "NAUSEA"),
    stringsAsFactors = FALSE
  )
  def <- list(key_vars = list(AE = c("USUBJID", "AESEQ")))
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list(AE = ae)
  ctx$current_dataset <- "AE"
  ctx$define <- def
  out <- herald:::op_key_not_unique_per_define(ae, ctx)
  expect_equal(out, c(TRUE, TRUE, FALSE))
})

test_that("key_not_unique_per_define passes when keys are unique", {
  ae <- data.frame(
    USUBJID = c("S1", "S2"),
    AESEQ = c(1L, 1L),
    stringsAsFactors = FALSE
  )
  def <- list(key_vars = list(AE = c("USUBJID", "AESEQ")))
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list(AE = ae)
  ctx$current_dataset <- "AE"
  ctx$define <- def
  out <- herald:::op_key_not_unique_per_define(ae, ctx)
  expect_equal(out, c(FALSE, FALSE))
})

test_that("key_not_unique_per_define returns NA advisory when define is absent", {
  ae <- data.frame(USUBJID = c("S1"), AESEQ = 1L, stringsAsFactors = FALSE)
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list(AE = ae)
  ctx$current_dataset <- "AE"
  # no ctx$define set
  out <- herald:::op_key_not_unique_per_define(ae, ctx)
  expect_true(is.na(out[[1L]]))
})

test_that("key_not_unique_per_define returns NA when no key_vars for dataset", {
  ae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  def <- list(key_vars = list(DM = c("USUBJID")))
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list(AE = ae)
  ctx$current_dataset <- "AE"
  ctx$define <- def
  out <- herald:::op_key_not_unique_per_define(ae, ctx)
  expect_true(is.na(out[[1L]]))
})

test_that("key_not_unique_per_define returns NA when all key cols absent from data", {
  ae <- data.frame(AEDECOD = "HEADACHE", stringsAsFactors = FALSE)
  def <- list(key_vars = list(AE = c("USUBJID", "AESEQ")))
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list(AE = ae)
  ctx$current_dataset <- "AE"
  ctx$define <- def
  out <- herald:::op_key_not_unique_per_define(ae, ctx)
  expect_true(is.na(out[[1L]]))
})

test_that("key_not_unique_per_define returns logical(0) for empty dataset", {
  ae <- data.frame(USUBJID = character(0), AESEQ = integer(0),
                   stringsAsFactors = FALSE)
  def <- list(key_vars = list(AE = c("USUBJID", "AESEQ")))
  ctx <- herald:::new_herald_ctx()
  ctx$datasets <- list(AE = ae)
  ctx$current_dataset <- "AE"
  ctx$define <- def
  out <- herald:::op_key_not_unique_per_define(ae, ctx)
  expect_length(out, 0L)
})
