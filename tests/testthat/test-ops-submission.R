# Tests for Q9 submission-level ops:
#   op_study_metadata_is, op_ref_column_domains_exist

# ---------------------------------------------------------------------------
# op_study_metadata_is
# ---------------------------------------------------------------------------

test_that("op_study_metadata_is returns NA when study_metadata is NULL", {
  df <- data.frame(X = 1:3, stringsAsFactors = FALSE)
  ctx <- list(study_metadata = NULL)
  out <- herald:::op_study_metadata_is(df, ctx, key = "collected_domains", value = "MB")
  expect_equal(out, rep(NA, 3L))
})

test_that("op_study_metadata_is returns NA when ctx is NULL", {
  df <- data.frame(X = 1:2, stringsAsFactors = FALSE)
  out <- herald:::op_study_metadata_is(df, NULL, key = "collected_domains", value = "MB")
  expect_equal(out, rep(NA, 2L))
})

test_that("op_study_metadata_is returns TRUE when value is in collected_domains", {
  df <- data.frame(X = 1:2, stringsAsFactors = FALSE)
  ctx <- list(study_metadata = list(collected_domains = c("MB", "PC", "LB")))
  out <- herald:::op_study_metadata_is(df, ctx, key = "collected_domains", value = "MB")
  expect_equal(out, rep(TRUE, 2L))
})

test_that("op_study_metadata_is returns FALSE when value is absent from collected_domains", {
  df <- data.frame(X = 1:2, stringsAsFactors = FALSE)
  ctx <- list(study_metadata = list(collected_domains = c("LB", "VS")))
  out <- herald:::op_study_metadata_is(df, ctx, key = "collected_domains", value = "MB")
  expect_equal(out, rep(FALSE, 2L))
})

test_that("op_study_metadata_is is case-insensitive", {
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  ctx <- list(study_metadata = list(collected_domains = c("mb", "lB")))
  out <- herald:::op_study_metadata_is(df, ctx, key = "collected_domains", value = "MB")
  expect_equal(out[[1L]], TRUE)
})

test_that("op_study_metadata_is returns FALSE when key is absent from study_metadata", {
  df <- data.frame(X = 1L, stringsAsFactors = FALSE)
  ctx <- list(study_metadata = list(study_type = "Phase III"))
  out <- herald:::op_study_metadata_is(df, ctx, key = "collected_domains", value = "MB")
  expect_equal(out, rep(FALSE, 1L))
})

test_that("op_study_metadata_is returns logical(0) for 0-row data", {
  df <- data.frame(X = integer(0), stringsAsFactors = FALSE)
  ctx <- list(study_metadata = list(collected_domains = c("MB")))
  out <- herald:::op_study_metadata_is(df, ctx, key = "collected_domains", value = "MB")
  expect_equal(out, rep(TRUE, 0L))
})

# ---------------------------------------------------------------------------
# op_ref_column_domains_exist
# ---------------------------------------------------------------------------

test_that("op_ref_column_domains_exist fires when domain not in ctx$datasets", {
  relrec <- data.frame(RDOMAIN = c("DM", "XY"), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(DM = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(relrec, ctx, reference_column = "RDOMAIN")
  expect_equal(out[[1L]], FALSE)  # DM is present
  expect_equal(out[[2L]], TRUE)   # XY is absent
})

test_that("op_ref_column_domains_exist returns all FALSE when all domains present", {
  relrec <- data.frame(RDOMAIN = c("DM", "AE"), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(
    DM = data.frame(USUBJID = "S1"),
    AE = data.frame(USUBJID = "S1")
  ))
  out <- herald:::op_ref_column_domains_exist(relrec, ctx, reference_column = "RDOMAIN")
  expect_equal(any(out, na.rm = TRUE), FALSE)
})

test_that("op_ref_column_domains_exist returns NA for NA rows", {
  relrec <- data.frame(RDOMAIN = c("DM", NA_character_), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(DM = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(relrec, ctx, reference_column = "RDOMAIN")
  expect_equal(out[[1L]], FALSE)
  expect_true(is.na(out[[2L]]))
})

test_that("op_ref_column_domains_exist returns NA for empty-string rows", {
  relrec <- data.frame(RDOMAIN = c("AE", ""), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(AE = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(relrec, ctx, reference_column = "RDOMAIN")
  expect_equal(out[[1L]], FALSE)
  expect_true(is.na(out[[2L]]))
})

test_that("op_ref_column_domains_exist returns NA when column absent", {
  relrec <- data.frame(OTHER = "DM", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(DM = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(relrec, ctx, reference_column = "RDOMAIN")
  expect_true(is.na(out[[1L]]))
})

test_that("op_ref_column_domains_exist is case-insensitive on domain names", {
  relrec <- data.frame(RDOMAIN = "dm", stringsAsFactors = FALSE)
  ctx <- list(datasets = list(DM = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(relrec, ctx, reference_column = "RDOMAIN")
  expect_equal(out[[1L]], FALSE)
})

test_that("op_ref_column_domains_exist returns logical(0) for 0-row data", {
  relrec <- data.frame(RDOMAIN = character(0), stringsAsFactors = FALSE)
  ctx <- list(datasets = list(DM = data.frame(USUBJID = "S1")))
  out <- herald:::op_ref_column_domains_exist(relrec, ctx, reference_column = "RDOMAIN")
  expect_equal(length(out), 0L)
})

# ---------------------------------------------------------------------------
# validate() integration for Q9 rules
# ---------------------------------------------------------------------------

test_that("CG0368: validate fires when DM is absent", {
  ae <- data.frame(USUBJID = "S1", AEDECOD = "HEADACHE", stringsAsFactors = FALSE)
  result <- validate(
    files = list(AE = ae),
    rules = "CG0368",
    quiet = TRUE
  )
  expect_gt(nrow(result$findings), 0L)
  expect_equal(result$findings$rule_id[[1L]], "CG0368")
})

test_that("CG0368: validate passes when DM is present", {
  dm <- data.frame(USUBJID = "S1", STUDYID = "STUDY1", stringsAsFactors = FALSE)
  result <- validate(
    files = list(DM = dm),
    rules = "CG0368",
    quiet = TRUE
  )
  expect_equal(nrow(result$findings), 0L)
})

test_that("CG0646: validate fires when SJ dataset is present", {
  sj <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(
    files = list(SJ = sj),
    rules = "CG0646",
    quiet = TRUE
  )
  expect_gt(nrow(result$findings), 0L)
  expect_equal(result$findings$rule_id[[1L]], "CG0646")
})

test_that("CG0646: validate passes when SJ dataset is absent", {
  dm <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(
    files = list(DM = dm),
    rules = "CG0646",
    quiet = TRUE
  )
  expect_equal(nrow(result$findings), 0L)
})

test_that("CG0191: validate is advisory when study_metadata is NULL", {
  ae <- data.frame(USUBJID = "S1", stringsAsFactors = FALSE)
  result <- validate(
    files = list(AE = ae),
    rules = "CG0191",
    quiet = TRUE
  )
  # NA combinator -> no definitive firing, 0 findings
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
    USUBJID  = c("S1", "S1"),
    RDOMAIN  = c("DM", "XY"),
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
