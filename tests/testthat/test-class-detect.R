# -----------------------------------------------------------------------------
# test-fast-class-detect.R -- P21-style cascading class detection
# -----------------------------------------------------------------------------

test_that("named SDTM domains resolve via Stage 1 lookup", {
  expect_equal(herald:::infer_class("AE"), "EVENTS")
  expect_equal(herald:::infer_class("MH"), "EVENTS")
  expect_equal(herald:::infer_class("CM"), "INTERVENTIONS")
  expect_equal(herald:::infer_class("LB"), "FINDINGS")
  expect_equal(herald:::infer_class("FA"), "FINDINGS ABOUT")
  expect_equal(herald:::infer_class("DM"), "SPECIAL PURPOSE")
  expect_equal(herald:::infer_class("TV"), "TRIAL DESIGN")
  expect_equal(herald:::infer_class("RELREC"), "RELATIONSHIP")
})

test_that("SUPP-- domains resolve to RELATIONSHIP via prefix", {
  expect_equal(herald:::infer_class("SUPPAE"), "RELATIONSHIP")
  expect_equal(herald:::infer_class("SUPPDM"), "RELATIONSHIP")
  expect_equal(herald:::infer_class("SUPPLB"), "RELATIONSHIP")
})

test_that("ADaM named datasets resolve via Stage 1", {
  expect_equal(herald:::infer_class("ADSL"), "SUBJECT LEVEL ANALYSIS DATASET")
  expect_equal(herald:::infer_class("ADAE"), "OCCURRENCE DATA STRUCTURE")
})

test_that("ADLB / ADQS resolve to BDS via PARAMCD prototype (Stage 2)", {
  # ADaM-IG prototype: BDS datasets are identified by PARAMCD, PARAM, AVAL,
  # AVALC. An ADLB / ADQS dataset with PARAMCD is BDS.
  cols_bds <- c("USUBJID", "PARAMCD", "PARAM", "AVAL", "AVALC", "ADT")
  expect_equal(herald:::infer_class("ADLB", cols_bds), "BASIC DATA STRUCTURE")
  expect_equal(herald:::infer_class("ADQS", cols_bds), "BASIC DATA STRUCTURE")
})

test_that("AD-prefixed dataset without PARAMCD but with --TRT/--TERM is OCCDS", {
  # An ADXX dataset with ADXXTRT and no PARAMCD matches OCCDS prototype.
  cols_occds <- c("USUBJID", "ADXXSEQ", "ADXXTRT", "ADXXDECOD")
  expect_equal(
    herald:::infer_class("ADXX", cols_occds),
    "OCCURRENCE DATA STRUCTURE"
  )
})

test_that("AD-prefixed dataset with neither BDS nor OCCDS cues falls to ADAM OTHER", {
  cols_other <- c("USUBJID", "STUDYID", "COHORT")
  expect_equal(herald:::infer_class("ADMISC", cols_other), "ADAM OTHER")
})

test_that("custom SDTM domain inferred from topic variable", {
  # Unrecognized domain name "MYEVT" with MYEVTERM column -> EVENTS.
  cols <- c("USUBJID", "MYEVTERM", "MYEVSEQ")
  expect_equal(herald:::infer_class("MYEVT", cols), "EVENTS")
})

test_that("custom FINDINGS via --TESTCD", {
  cols <- c("USUBJID", "QQTESTCD", "QQORRES")
  expect_equal(herald:::infer_class("QQ", cols), "FINDINGS")
})

test_that("caller-supplied spec wins over auto-detection", {
  spec <- structure(
    list(
      ds_spec = data.frame(
        dataset = "AE",
        class = "EVENTS OVERRIDE",
        stringsAsFactors = FALSE
      )
    ),
    class = c("herald_spec", "list")
  )
  # Even though AE -> EVENTS via the map, spec takes precedence.
  expect_equal(
    herald:::infer_class("AE", c("AETERM"), spec = spec),
    "EVENTS OVERRIDE"
  )
})

test_that("unknown dataset with no identifying columns yields NA", {
  expect_true(is.na(herald:::infer_class("NOMATCH", c("X", "Y", "Z"))))
})
