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

# ---- .class_of_dataset_name (Stage 1) low-level tests ------------------------

test_that(".class_of_dataset_name returns NA for length != 1", {
  expect_true(is.na(herald:::.class_of_dataset_name(character())))
  expect_true(is.na(herald:::.class_of_dataset_name(c("AE", "DM"))))
})

test_that(".class_of_dataset_name returns NA for empty string", {
  expect_true(is.na(herald:::.class_of_dataset_name("")))
})

test_that(".class_of_dataset_name handles SUPP-- prefix pattern", {
  expect_equal(herald:::.class_of_dataset_name("SUPPAE"), "RELATIONSHIP")
  expect_equal(herald:::.class_of_dataset_name("SUPPDM"), "RELATIONSHIP")
})

test_that(".class_of_dataset_name is case-insensitive", {
  expect_equal(herald:::.class_of_dataset_name("ae"), "EVENTS")
  expect_equal(herald:::.class_of_dataset_name("Lb"), "FINDINGS")
})

test_that(".class_of_dataset_name returns NA for unrecognized name", {
  expect_true(is.na(herald:::.class_of_dataset_name("ZZUNKNOWN")))
})

test_that(".class_of_dataset_name resolves ADaMIG-MD datasets", {
  expect_equal(herald:::.class_of_dataset_name("ADDL"), "DEVICE LEVEL ANALYSIS DATASET")
  expect_equal(herald:::.class_of_dataset_name("ADMDBD"), "MEDICAL DEVICE BASIC DATA STRUCTURE")
})

test_that(".class_of_dataset_name resolves STUDY REFERENCE (OI)", {
  expect_equal(herald:::.class_of_dataset_name("OI"), "STUDY REFERENCE")
})

# ---- .expand_col_pattern -----------------------------------------------------

test_that(".expand_col_pattern expands --STEM using first two chars of ds_name", {
  result <- herald:::.expand_col_pattern("--TERM", "AE")
  expect_equal(result, "AETERM")
})

test_that(".expand_col_pattern upcases literal patterns", {
  result <- herald:::.expand_col_pattern("paramcd", "ADLB")
  expect_equal(result, "PARAMCD")
})

test_that(".expand_col_pattern handles longer domain prefix", {
  result <- herald:::.expand_col_pattern("--TESTCD", "LB")
  expect_equal(result, "LBTESTCD")
})

# ---- .class_from_topic (Stage 2) require_none branch -------------------------

test_that(".class_from_topic require_none excludes matching prototype", {
  # OCCDS prototype requires --TRT but requires_none PARAMCD
  # BDS wins because PARAMCD satisfies its require_any
  cols <- c("USUBJID", "ADXXTRT", "PARAMCD")
  result <- herald:::.class_from_topic("ADXX", cols)
  expect_equal(result, "BASIC DATA STRUCTURE")
})

test_that(".class_from_topic returns NA when no prototype matches", {
  result <- herald:::.class_from_topic("ZZUNKNOWN", c("X", "Y"))
  expect_true(is.na(result))
})

test_that(".class_from_topic matches RELATIONSHIP via QNAM", {
  result <- herald:::.class_from_topic("SUPPAE", c("USUBJID", "QNAM", "QVAL"))
  expect_equal(result, "RELATIONSHIP")
})

test_that(".class_from_topic uses relaxed prefix match for custom domains", {
  # Custom domain with 3-char prefix: "MYE" + "TERM" -> MYETERM
  cols <- c("USUBJID", "MYETERM", "MYESEQ")
  result <- herald:::.class_from_topic("MYEV", cols)
  expect_equal(result, "EVENTS")
})

# ---- infer_class spec paths --------------------------------------------------

test_that("infer_class resolves via spec with capitalized column names", {
  spec <- structure(
    list(
      ds_spec = data.frame(
        Dataset = "LB",
        Class = "FINDINGS OVERRIDE",
        stringsAsFactors = FALSE
      )
    ),
    class = c("herald_spec", "list")
  )
  expect_equal(
    herald:::infer_class("LB", c("LBTESTCD"), spec = spec),
    "FINDINGS OVERRIDE"
  )
})

test_that("infer_class skips spec when class cell is NA and falls to Stage 1", {
  spec <- structure(
    list(
      ds_spec = data.frame(
        dataset = "LB",
        class = NA_character_,
        stringsAsFactors = FALSE
      )
    ),
    class = c("herald_spec", "list")
  )
  result <- herald:::infer_class("LB", c("LBTESTCD"), spec = spec)
  expect_equal(result, "FINDINGS")
})

test_that("infer_class with spec that has no ds_spec falls through to Stage 1", {
  spec <- structure(list(ds_spec = NULL), class = c("herald_spec", "list"))
  expect_equal(herald:::infer_class("CM"), "INTERVENTIONS")
})
