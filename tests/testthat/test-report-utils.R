# test-report-utils.R -- shared report helper functions
# Covers: `%|NA|%`, tally_col, summarise_counts, applied_rules,
#         format_duration_secs, iso_timestamp, dataset_meta_tbl,
#         op_errors_list, resolve_report_format, check_report_inputs

# ---- %|NA|% ------------------------------------------------------------------

test_that("%|NA|% replaces NA with replacement value", {
  x <- c(1L, NA_integer_, 3L)
  result <- herald:::`%|NA|%`(x, 0L)
  expect_equal(result, c(1L, 0L, 3L))
})

test_that("%|NA|% leaves non-NA values unchanged", {
  x <- c("a", "b", "c")
  result <- herald:::`%|NA|%`(x, "z")
  expect_equal(result, c("a", "b", "c"))
})

test_that("%|NA|% works on all-NA vector", {
  x <- c(NA_character_, NA_character_)
  result <- herald:::`%|NA|%`(x, "fallback")
  expect_equal(result, c("fallback", "fallback"))
})

# ---- tally_col ---------------------------------------------------------------

test_that("tally_col returns sorted named integer vector", {
  x <- c("fired", "fired", "advisory", "fired")
  result <- herald:::tally_col(x)
  expect_type(result, "integer")
  expect_named(result)
  # highest count first
  expect_equal(result[["fired"]], 3L)
  expect_equal(result[["advisory"]], 1L)
})

test_that("tally_col returns empty named integer vector for all-NA input", {
  result <- herald:::tally_col(c(NA_character_, NA_character_))
  expect_type(result, "integer")
  expect_length(result, 0L)
  expect_named(result, character())
})

test_that("tally_col returns empty named integer vector for zero-length input", {
  result <- herald:::tally_col(character())
  expect_type(result, "integer")
  expect_length(result, 0L)
})

test_that("tally_col drops NAs and only counts non-NA values", {
  x <- c("a", NA_character_, "a", "b")
  result <- herald:::tally_col(x)
  expect_equal(sum(result), 3L)
  expect_equal(result[["a"]], 2L)
})

# ---- summarise_counts --------------------------------------------------------

test_that("summarise_counts returns named list with all four keys", {
  findings <- data.frame(
    status   = c("fired", "advisory", "fired"),
    severity = c("Error", "Warning", "Error"),
    dataset  = c("AE", "DM", "AE"),
    rule_id  = c("R001", "R002", "R001"),
    stringsAsFactors = FALSE
  )
  result <- herald:::summarise_counts(findings)
  expect_named(result, c("by_status", "by_severity", "by_dataset", "by_rule"))
  expect_equal(result$by_status[["fired"]], 2L)
  expect_equal(result$by_status[["advisory"]], 1L)
})

test_that("summarise_counts returns empty vectors for zero-row findings", {
  findings <- data.frame(
    status = character(), severity = character(),
    dataset = character(), rule_id = character(),
    stringsAsFactors = FALSE
  )
  result <- herald:::summarise_counts(findings)
  expect_length(result$by_status, 0L)
  expect_length(result$by_severity, 0L)
})

test_that("summarise_counts returns empty vectors when col is missing", {
  # findings with only some columns
  findings <- data.frame(x = 1L)
  result <- herald:::summarise_counts(findings)
  expect_length(result$by_status, 0L)
})

# ---- applied_rules -----------------------------------------------------------

test_that("applied_rules joins fired_n and advisory_n onto rule catalog", {
  rc <- data.frame(
    id        = c("R001", "R002", "R003"),
    authority = "SDTM",
    standard  = "SDTMIG",
    severity  = c("Error", "Warning", "Error"),
    message   = c("msg1", "msg2", "msg3"),
    stringsAsFactors = FALSE
  )
  findings <- data.frame(
    rule_id = c("R001", "R001", "R002"),
    status  = c("fired", "fired", "advisory"),
    stringsAsFactors = FALSE
  )
  result <- herald:::applied_rules(rc, findings)
  expect_s3_class(result, "tbl_df")
  expect_equal(result$fired_n[result$id == "R001"], 2L)
  expect_equal(result$advisory_n[result$id == "R002"], 1L)
  expect_equal(result$fired_n[result$id == "R003"], 0L)
})

test_that("applied_rules returns empty tibble for NULL/empty rule catalog", {
  result <- herald:::applied_rules(data.frame(), data.frame(rule_id = character(), status = character()))
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true("fired_n" %in% names(result))
})

test_that("applied_rules handles non-data-frame rule_catalog gracefully", {
  result <- herald:::applied_rules(NULL, data.frame(rule_id = "R1", status = "fired"))
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
})

# ---- format_duration_secs ----------------------------------------------------

test_that("format_duration_secs returns 0 for NULL", {
  expect_equal(herald:::format_duration_secs(NULL), 0)
})

test_that("format_duration_secs converts difftime to numeric seconds", {
  d <- as.difftime(90, units = "secs")
  result <- herald:::format_duration_secs(d)
  expect_equal(result, 90)
})

test_that("format_duration_secs rounds to 2 decimal places", {
  d <- as.difftime(1.2345, units = "secs")
  result <- herald:::format_duration_secs(d)
  expect_equal(result, 1.23)
})

# ---- iso_timestamp -----------------------------------------------------------

test_that("iso_timestamp returns ISO-8601 UTC string", {
  t <- as.POSIXct("2024-06-15 12:00:00", tz = "UTC")
  result <- herald:::iso_timestamp(t)
  expect_equal(result, "2024-06-15T12:00:00Z")
})

test_that("iso_timestamp default arg returns current time string", {
  result <- herald:::iso_timestamp()
  expect_match(result, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
})

# ---- dataset_meta_tbl --------------------------------------------------------

test_that("dataset_meta_tbl returns empty tibble when dataset_meta is empty list", {
  result <- herald:::dataset_meta_tbl(list(), data.frame(dataset = character(), status = character()))
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true(all(c("name", "rows", "cols", "class", "label", "fired_n", "advisory_n") %in% names(result)))
})

test_that("dataset_meta_tbl populates rows/cols and joins finding counts", {
  meta <- list(
    AE = list(rows = 10L, cols = 5L, class = "EVENTS", label = "Adverse Events"),
    DM = list(rows = 50L, cols = 20L, class = "SPECIAL PURPOSE", label = "Demographics")
  )
  findings <- data.frame(
    dataset = c("AE", "AE", "DM"),
    status  = c("fired", "fired", "advisory"),
    stringsAsFactors = FALSE
  )
  result <- herald:::dataset_meta_tbl(meta, findings)
  expect_s3_class(result, "tbl_df")
  ae_fired  <- result$fired_n[result$name == "AE"]
  dm_adv    <- result$advisory_n[result$name == "DM"]
  ae_rows   <- result$rows[result$name == "AE"]
  expect_equal(unname(ae_fired), 2L)
  expect_equal(unname(dm_adv), 1L)
  expect_equal(unname(ae_rows), 10L)
})

test_that("dataset_meta_tbl handles NULL values in meta entries", {
  meta <- list(
    AE = list(rows = NULL, cols = NULL, class = NULL, label = NULL)
  )
  findings <- data.frame(dataset = character(), status = character(), stringsAsFactors = FALSE)
  result <- herald:::dataset_meta_tbl(meta, findings)
  expect_equal(nrow(result), 1L)
  expect_true(is.na(result$rows[1L]))
  expect_equal(result$fired_n[1L], 0L)
})

# ---- op_errors_list ----------------------------------------------------------

test_that("op_errors_list returns empty list for no errors", {
  result <- herald:::op_errors_list(list())
  expect_type(result, "list")
  expect_length(result, 0L)
})

test_that("op_errors_list normalises op errors to character fields", {
  errs <- list(
    list(rule_id = "R001", operator = "iso8601", dataset = "AE", message = "bad date")
  )
  result <- herald:::op_errors_list(errs)
  expect_length(result, 1L)
  expect_equal(result[[1L]]$rule_id, "R001")
  expect_equal(result[[1L]]$operator, "iso8601")
  expect_equal(result[[1L]]$dataset, "AE")
  expect_equal(result[[1L]]$message, "bad date")
})

test_that("op_errors_list handles NULL fields in error entries", {
  errs <- list(
    list(rule_id = NULL, operator = NULL, dataset = NULL, message = NULL)
  )
  result <- herald:::op_errors_list(errs)
  expect_length(result, 1L)
  # NULL fields should become NA_character_
  expect_equal(result[[1L]]$rule_id, NA_character_)
})

# ---- resolve_report_format ---------------------------------------------------

test_that("resolve_report_format infers html from .html extension", {
  result <- herald:::resolve_report_format("output/report.html", format = NULL)
  expect_equal(result, "html")
})

test_that("resolve_report_format infers xlsx from .xlsx extension", {
  result <- herald:::resolve_report_format("output/report.xlsx", format = NULL)
  expect_equal(result, "xlsx")
})

test_that("resolve_report_format infers json from .json extension", {
  result <- herald:::resolve_report_format("output/report.json", format = NULL)
  expect_equal(result, "json")
})

test_that("resolve_report_format uses explicit format arg over extension", {
  result <- herald:::resolve_report_format("output/report.txt", format = "json")
  expect_equal(result, "json")
})

test_that("resolve_report_format errors for path with no extension", {
  expect_error(
    herald:::resolve_report_format("output/noextension", format = NULL),
    class = "herald_error_report"
  )
})

test_that("resolve_report_format errors for unknown format", {
  expect_error(
    herald:::resolve_report_format("output/file.pdf", format = NULL),
    class = "herald_error_report"
  )
})

test_that("resolve_report_format errors for unknown explicit format", {
  expect_error(
    herald:::resolve_report_format("output/file.html", format = "csv"),
    class = "herald_error_report"
  )
})

# ---- check_report_inputs -----------------------------------------------------

test_that("check_report_inputs errors for non-herald_result x", {
  tmp <- withr::local_tempdir()
  path <- file.path(tmp, "report.html")
  expect_error(
    herald:::check_report_inputs(list(), path),
    class = "herald_error_report"
  )
})

test_that("check_report_inputs errors for non-existent parent directory", {
  fake_result <- structure(list(), class = "herald_result")
  expect_error(
    herald:::check_report_inputs(fake_result, "/nonexistent/dir/report.html"),
    class = "herald_error_file"
  )
})

test_that("check_report_inputs returns TRUE invisibly for valid inputs", {
  fake_result <- structure(list(), class = "herald_result")
  tmp <- withr::local_tempdir()
  path <- file.path(tmp, "report.html")
  result <- herald:::check_report_inputs(fake_result, path)
  expect_true(result)
})
