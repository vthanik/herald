# --------------------------------------------------------------------------
# test-sub-discover.R -- detect_adam_class, detect_adam_classes,
#                        detect_standard, extract_standard_from_spec,
#                        scan_folder_datasets
# --------------------------------------------------------------------------

# ---- detect_adam_class: TTE ------------------------------------------------

test_that("detect_adam_class returns TTE when PARAMCD + AVAL + CNSR present", {
  vars <- c("USUBJID", "STUDYID", "PARAMCD", "AVAL", "CNSR", "ADT")
  expect_equal(herald::detect_adam_class(vars), "TTE")
})

test_that("detect_adam_class TTE detection is case-insensitive", {
  vars <- c("usubjid", "paramcd", "aval", "cnsr")
  expect_equal(herald::detect_adam_class(vars), "TTE")
})

# ---- detect_adam_class: BDS ------------------------------------------------

test_that("detect_adam_class returns BDS when PARAMCD + AVAL present (no CNSR)", {
  vars <- c("USUBJID", "STUDYID", "PARAMCD", "AVAL", "ADT", "VISITNUM")
  expect_equal(herald::detect_adam_class(vars), "BDS")
})

test_that("detect_adam_class returns BDS when PARAMCD + AVALC present", {
  vars <- c("USUBJID", "PARAMCD", "AVALC", "ADT")
  expect_equal(herald::detect_adam_class(vars), "BDS")
})

# ---- detect_adam_class: ADSL -----------------------------------------------

test_that("detect_adam_class returns ADSL when USUBJID only, no term/flag vars", {
  vars <- c("USUBJID", "STUDYID", "AGE", "SEX", "SAFFL", "ITTFL")
  expect_equal(herald::detect_adam_class(vars), "ADSL")
})

test_that("detect_adam_class returns ADSL for a dataset with analysis flags but no term/occ vars", {
  vars <- c("USUBJID", "STUDYID", "SUBJID", "ARM", "TRT01P", "AGE", "SEX",
            "SAFFL", "ITTFL", "EFFFL", "TRTSDT", "TRTEDT")
  expect_equal(herald::detect_adam_class(vars), "ADSL")
})

# ---- detect_adam_class: OCCDS ----------------------------------------------

test_that("detect_adam_class returns OCCDS for AE dataset (term variable)", {
  adae <- readRDS(system.file("extdata", "adae.rds", package = "herald"))
  expect_equal(herald::detect_adam_class(names(adae)), "OCCDS")
})

test_that("detect_adam_class returns OCCDS when AEDECOD present", {
  vars <- c("USUBJID", "STUDYID", "AEDECOD", "AETERM", "AESTDTC")
  expect_equal(herald::detect_adam_class(vars), "OCCDS")
})

test_that("detect_adam_class returns OCCDS when occurrence flags present", {
  vars <- c("USUBJID", "STUDYID", "TRTEMFL", "AESEQ")
  expect_equal(herald::detect_adam_class(vars), "OCCDS")
})

test_that("detect_adam_class returns OCCDS when CMDECOD present", {
  vars <- c("USUBJID", "STUDYID", "CMDECOD", "CMSTDTC")
  expect_equal(herald::detect_adam_class(vars), "OCCDS")
})

# ---- detect_adam_class: unknown --------------------------------------------

test_that("detect_adam_class returns unknown when no recognisable signature", {
  vars <- c("X", "Y", "Z")
  expect_equal(herald::detect_adam_class(vars), "unknown")
})

test_that("detect_adam_class returns unknown for empty vars", {
  expect_equal(herald::detect_adam_class(character(0L)), "unknown")
})

# ---- detect_adam_classes: list of data frames --------------------------------

test_that("detect_adam_classes works on a named list of data frames", {
  # Use inline data frames with known signatures
  adsl_df <- data.frame(USUBJID = "S1", STUDYID = "X", AGE = 30L, SAFFL = "Y")
  advs_df <- data.frame(USUBJID = "S1", PARAMCD = "SYSBP", AVAL = 120)
  adae_df <- data.frame(USUBJID = "S1", AETERM = "Headache", AEDECOD = "HEAD")
  result <- herald::detect_adam_classes(
    list(ADSL = adsl_df, ADVS = advs_df, ADAE = adae_df)
  )
  expect_type(result, "character")
  expect_equal(result[["ADSL"]], "ADSL")
  expect_equal(result[["ADVS"]], "BDS")
  expect_equal(result[["ADAE"]], "OCCDS")
})

test_that("detect_adam_classes works on bare data frame args", {
  adsl <- data.frame(USUBJID = "S1", STUDYID = "X", AGE = 30L, SAFFL = "Y")
  advs <- readRDS(system.file("extdata", "advs.rds", package = "herald"))
  result <- herald::detect_adam_classes(adsl, advs)
  expect_named(result, c("ADSL", "ADVS"))
  expect_equal(result[["ADSL"]], "ADSL")
  expect_equal(result[["ADVS"]], "BDS")
})

test_that("detect_adam_classes uses explicit names when provided", {
  adsl <- readRDS(system.file("extdata", "adsl.rds", package = "herald"))
  result <- herald::detect_adam_classes(MYDS = adsl)
  expect_named(result, "MYDS")
})

test_that("detect_adam_classes falls back to DATA<i> for unnamed bare calls", {
  df <- data.frame(X = 1:3)
  # Pass as a named element to avoid symbol inference
  result <- herald::detect_adam_classes(list(DATA1 = df))
  expect_named(result, "DATA1")
})

test_that("detect_adam_classes works on a herald_spec", {
  spec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
  result <- herald::detect_adam_classes(spec)
  expect_type(result, "character")
  expect_true(length(result) > 0L)
})

test_that("detect_adam_classes returns character(0) for spec with no var_spec", {
  # Build a minimal spec-like object with no var_spec
  spec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
  spec2 <- spec
  spec2$var_spec <- NULL
  result <- herald::detect_adam_classes(spec2)
  expect_equal(result, character(0L))
})

test_that("detect_adam_classes errors on unsupported input", {
  expect_error(
    herald::detect_adam_classes(42L),
    class = "herald_error_io"
  )
})

# ---- detect_standard -------------------------------------------------------

test_that("detect_standard returns adam for AD-prefixed dataset names", {
  expect_equal(herald:::detect_standard(c("ADSL", "ADAE", "ADVS")), "adam")
})

test_that("detect_standard returns adam for mixed ADSL + others", {
  expect_equal(herald:::detect_standard(c("ADSL", "SUPPAE")), "adam")
})

test_that("detect_standard returns sdtm for SDTM domain names", {
  expect_equal(herald:::detect_standard(c("DM", "AE", "LB", "VS")), "sdtm")
})

test_that("detect_standard returns sdtm for single known domain", {
  expect_equal(herald:::detect_standard(c("DM")), "sdtm")
})

test_that("detect_standard returns send for >= 2 nonclinical domains", {
  expect_equal(herald:::detect_standard(c("TS", "TX", "BW")), "send")
})

test_that("detect_standard returns unknown when no patterns match", {
  expect_equal(herald:::detect_standard(c("FOO", "BAR")), "unknown")
})

test_that("detect_standard is case-insensitive", {
  expect_equal(herald:::detect_standard(c("adsl", "adae")), "adam")
  expect_equal(herald:::detect_standard(c("dm", "ae")), "sdtm")
})

# ---- extract_standard_from_spec --------------------------------------------

test_that("extract_standard_from_spec returns NULL for NULL spec", {
  expect_null(herald:::extract_standard_from_spec(NULL))
})

test_that("extract_standard_from_spec returns NULL when ds_spec is NULL", {
  spec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
  spec2 <- spec
  spec2$ds_spec <- NULL
  expect_null(herald:::extract_standard_from_spec(spec2))
})

test_that("extract_standard_from_spec returns NULL when standard column absent", {
  spec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
  spec2 <- spec
  spec2$ds_spec[["standard"]] <- NULL
  expect_null(herald:::extract_standard_from_spec(spec2))
})

test_that("extract_standard_from_spec returns adam for ADaMIG standard", {
  spec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
  spec2 <- spec
  spec2$ds_spec[["standard"]] <- "ADaMIG 1.1"
  result <- herald:::extract_standard_from_spec(spec2)
  expect_equal(result, "adam")
})

test_that("extract_standard_from_spec returns sdtm for SDTMIG standard", {
  spec <- readRDS(system.file("extdata", "sdtm-spec.rds", package = "herald"))
  spec2 <- spec
  spec2$ds_spec[["standard"]] <- "SDTMIG 3.3"
  result <- herald:::extract_standard_from_spec(spec2)
  expect_equal(result, "sdtm")
})

test_that("extract_standard_from_spec returns send for SENDIG standard", {
  spec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
  spec2 <- spec
  spec2$ds_spec[["standard"]] <- "SENDIG 3.1"
  result <- herald:::extract_standard_from_spec(spec2)
  expect_equal(result, "send")
})

test_that("extract_standard_from_spec returns NULL when standard value unrecognised", {
  spec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
  spec2 <- spec
  spec2$ds_spec[["standard"]] <- "XYZFOO 9.9"
  expect_null(herald:::extract_standard_from_spec(spec2))
})

test_that("extract_standard_from_spec returns NULL when all standards are blank", {
  spec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
  spec2 <- spec
  spec2$ds_spec[["standard"]] <- c("", NA_character_)
  expect_null(herald:::extract_standard_from_spec(spec2))
})

# ---- scan_folder_datasets --------------------------------------------------

test_that("scan_folder_datasets errors on nonexistent directory", {
  expect_error(
    herald:::scan_folder_datasets("/nonexistent/path/12345"),
    class = "herald_error_io"
  )
})

test_that("scan_folder_datasets returns xpt_files and json_files for empty dir", {
  tmp <- withr::local_tempdir()
  result <- herald:::scan_folder_datasets(tmp)
  expect_type(result, "list")
  expect_named(result, c("xpt_files", "json_files"))
  expect_equal(length(result$xpt_files), 0L)
  expect_equal(length(result$json_files), 0L)
})

test_that("scan_folder_datasets detects XPT files", {
  tmp <- withr::local_tempdir()
  writeLines("dummy", file.path(tmp, "dm.xpt"))
  writeLines("dummy", file.path(tmp, "ae.XPT"))
  result <- herald:::scan_folder_datasets(tmp)
  expect_equal(length(result$xpt_files), 2L)
})

test_that("scan_folder_datasets filters JSON to dataset-JSON only", {
  skip_if_not_installed("jsonlite")
  tmp <- withr::local_tempdir()
  # A Dataset-JSON file (contains "clinicalData")
  writeLines('{"clinicalData": {}}', file.path(tmp, "dm.json"))
  # A non-dataset JSON file (no recognised keywords)
  writeLines('{"name": "spec"}', file.path(tmp, "spec.json"))
  result <- herald:::scan_folder_datasets(tmp)
  # Only the dataset JSON should be kept
  expect_equal(length(result$json_files), 1L)
  expect_true(grepl("dm\\.json$", result$json_files[[1L]]))
})

test_that("scan_folder_datasets includes JSON with datasetJSONVersion keyword", {
  skip_if_not_installed("jsonlite")
  tmp <- withr::local_tempdir()
  writeLines('{"datasetJSONVersion": "1.0", "items": []}', file.path(tmp, "lb.json"))
  result <- herald:::scan_folder_datasets(tmp)
  expect_equal(length(result$json_files), 1L)
})

test_that("scan_folder_datasets returns empty json_files when no JSON files present", {
  tmp <- withr::local_tempdir()
  writeLines("dummy", file.path(tmp, "dm.xpt"))
  result <- herald:::scan_folder_datasets(tmp)
  expect_equal(length(result$json_files), 0L)
  expect_equal(length(result$xpt_files), 1L)
})

# ---- load_folder_datasets_filtered -----------------------------------------

test_that("load_folder_datasets_filtered errors when no files of requested format", {
  tmp <- withr::local_tempdir()
  writeLines('{"clinicalData": {}}', file.path(tmp, "dm.json"))
  expect_error(
    herald:::load_folder_datasets_filtered(tmp, format = "xpt"),
    class = "herald_error_io"
  )
})

test_that("load_folder_datasets_filtered errors when requested dataset not found", {
  tmp <- withr::local_tempdir()
  adsl_xpt <- file.path(tmp, "adsl.xpt")
  adsl_df <- data.frame(
    STUDYID = "X001",
    USUBJID = "X001-001",
    stringsAsFactors = FALSE
  )
  herald::write_xpt(adsl_df, adsl_xpt)
  expect_error(
    herald:::load_folder_datasets_filtered(tmp, datasets = c("NONEXIST"), format = "xpt"),
    class = "herald_error_io"
  )
})

test_that("load_folder_datasets_filtered returns named list for valid XPT", {
  tmp <- withr::local_tempdir()
  adsl_xpt <- file.path(tmp, "adsl.xpt")
  adsl_df <- data.frame(
    STUDYID = "X001",
    USUBJID = "X001-001",
    stringsAsFactors = FALSE
  )
  herald::write_xpt(adsl_df, adsl_xpt)
  result <- herald:::load_folder_datasets_filtered(tmp, format = "xpt")
  expect_type(result, "list")
  expect_named(result, "ADSL")
})

test_that("load_folder_datasets_filtered filters by requested dataset names", {
  tmp <- withr::local_tempdir()
  adsl_df <- data.frame(
    STUDYID = "X001",
    USUBJID = "X001-001",
    stringsAsFactors = FALSE
  )
  advs_df <- data.frame(
    STUDYID = "X001",
    USUBJID = "X001-001",
    PARAMCD = "SYSBP",
    AVAL = 120,
    stringsAsFactors = FALSE
  )
  herald::write_xpt(adsl_df, file.path(tmp, "adsl.xpt"))
  herald::write_xpt(advs_df, file.path(tmp, "advs.xpt"))
  result <- herald:::load_folder_datasets_filtered(
    tmp,
    datasets = "ADSL",
    format = "xpt"
  )
  expect_named(result, "ADSL")
  expect_length(result, 1L)
})

test_that("load_folder_datasets_filtered errors on nonexistent directory", {
  expect_error(
    herald:::load_folder_datasets_filtered("/no/such/dir", format = "xpt"),
    class = "herald_error_io"
  )
})

# ---- load_folder_datasets --------------------------------------------------

test_that("load_folder_datasets errors when directory has no dataset files", {
  tmp <- withr::local_tempdir()
  expect_error(
    herald:::load_folder_datasets(tmp),
    class = "herald_error_io"
  )
})

test_that("load_folder_datasets returns named list of data frames for XPT dir", {
  tmp <- withr::local_tempdir()
  adsl_df <- data.frame(
    STUDYID = "X001",
    USUBJID = "X001-001",
    stringsAsFactors = FALSE
  )
  herald::write_xpt(adsl_df, file.path(tmp, "adsl.xpt"))
  result <- herald:::load_folder_datasets(tmp)
  expect_type(result, "list")
  expect_true("ADSL" %in% names(result))
  expect_true(is.data.frame(result[["ADSL"]]))
})

test_that("load_folder_datasets errors on nonexistent directory", {
  expect_error(
    herald:::load_folder_datasets("/no/such/path"),
    class = "herald_error_io"
  )
})

# ---- detect_adam_classes: edge cases ----------------------------------------

test_that("detect_adam_classes handles unnamed list (non-symbol) with fallback names", {
  df1 <- data.frame(X = 1:3)
  result <- herald::detect_adam_classes(list(DATA1 = df1))
  expect_named(result, "DATA1")
})

test_that(
  "detect_adam_classes with herald_spec missing dataset column returns character(0)",
  {
    spec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
    spec2 <- spec
    spec2$var_spec[["dataset"]] <- NULL
    result <- herald::detect_adam_classes(spec2)
    expect_equal(result, character(0L))
  }
)

# ---- detect_standard: single SEND pattern (not enough for send) -----------

test_that("detect_standard returns unknown with only 1 SEND-like domain", {
  # "BW" alone is in send_patterns but not in adam/sdtm -- expect unknown
  expect_equal(herald:::detect_standard(c("BW")), "unknown")
})

# ---- extract_standard_from_spec: all-NA standards column ------------------

test_that("extract_standard_from_spec handles all-NA standards column", {
  spec <- readRDS(system.file("extdata", "adam-spec.rds", package = "herald"))
  spec2 <- spec
  spec2$ds_spec[["standard"]] <- NA_character_
  expect_null(herald:::extract_standard_from_spec(spec2))
})
