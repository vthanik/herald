# -----------------------------------------------------------------------------
# test-spec-report-html.R -- spec validation findings -> standalone HTML
# -----------------------------------------------------------------------------

# -- helpers ------------------------------------------------------------------

.make_spec_findings <- function(
  status = character(),
  severity = character(),
  rule_id = character(),
  dataset = character(),
  variable = character(),
  row = integer(),
  value = character(),
  message = character()
) {
  n <- length(status)
  tibble::tibble(
    rule_id = if (length(rule_id) == n) rule_id else rep(NA_character_, n),
    authority = rep(NA_character_, n),
    standard = rep(NA_character_, n),
    severity = if (length(severity) == n) severity else rep(NA_character_, n),
    severity_override = rep(NA_character_, n),
    status = status,
    dataset = if (length(dataset) == n) dataset else rep("", n),
    variable = if (length(variable) == n) variable else rep("", n),
    row = if (length(row) == n) row else rep(NA_integer_, n),
    value = if (length(value) == n) value else rep("", n),
    expected = rep("", n),
    message = if (length(message) == n) message else rep("", n),
    source_url = rep(NA_character_, n),
    p21_id_equivalent = rep(NA_character_, n),
    license = rep(NA_character_, n)
  )
}

# -- write_spec_report_html ---------------------------------------------------

test_that("write_spec_report_html writes a file and returns path invisibly", {
  path <- withr::local_tempfile(fileext = ".html")
  findings <- herald:::empty_findings()
  result <- herald:::write_spec_report_html(findings, path)
  expect_equal(result, path)
  expect_true(file.exists(path))
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_true(nchar(content) > 0L)
})

test_that("write_spec_report_html with zero findings produces 'No issues found' message", {
  path <- withr::local_tempfile(fileext = ".html")
  findings <- herald:::empty_findings()
  herald:::write_spec_report_html(findings, path)
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_true(grepl("No issues found", content))
})

test_that("write_spec_report_html with fired findings includes row content", {
  path <- withr::local_tempfile(fileext = ".html")
  findings <- .make_spec_findings(
    status = "fired",
    severity = "Reject",
    rule_id = "SPEC-001",
    dataset = "DM",
    variable = "USUBJID",
    row = 1L,
    value = "bad_value",
    message = "USUBJID is missing"
  )
  herald:::write_spec_report_html(findings, path)
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_true(grepl("SPEC-001", content))
  expect_true(grepl("REJECT", content))
  expect_true(grepl("DM", content))
})

test_that("write_spec_report_html with only advisory findings shows 'No fired issues'", {
  path <- withr::local_tempfile(fileext = ".html")
  findings <- .make_spec_findings(
    status = "advisory",
    severity = "Medium",
    rule_id = "SPEC-002",
    dataset = "AE",
    variable = "AETERM",
    row = 1L,
    value = "",
    message = "Advisory note"
  )
  herald:::write_spec_report_html(findings, path)
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_true(grepl("No fired issues", content))
})

# -- .spec_findings_rows ------------------------------------------------------

test_that(".spec_findings_rows returns empty-msg row for empty data frame", {
  out <- herald:::.spec_findings_rows(herald:::empty_findings())
  expect_true(grepl("No issues found", out))
})

test_that(".spec_findings_rows returns empty-msg for non-data-frame input", {
  out <- herald:::.spec_findings_rows(NULL)
  expect_true(grepl("No issues found", out))
})

test_that(".spec_findings_rows returns no-fired-issues row when all advisory", {
  f <- .make_spec_findings(status = "advisory", severity = "Medium")
  out <- herald:::.spec_findings_rows(f)
  expect_true(grepl("No fired issues", out))
})

test_that(".spec_findings_rows assigns sev-reject class to Reject severity", {
  f <- .make_spec_findings(status = "fired", severity = "Reject")
  out <- herald:::.spec_findings_rows(f)
  expect_true(grepl("sev-reject", out))
})

test_that(".spec_findings_rows assigns sev-reject class to error severity", {
  f <- .make_spec_findings(status = "fired", severity = "error")
  out <- herald:::.spec_findings_rows(f)
  expect_true(grepl("sev-reject", out))
})

test_that(".spec_findings_rows assigns sev-high class to High severity", {
  f <- .make_spec_findings(status = "fired", severity = "High")
  out <- herald:::.spec_findings_rows(f)
  expect_true(grepl("sev-high", out))
})

test_that(".spec_findings_rows assigns sev-high class to warning severity", {
  f <- .make_spec_findings(status = "fired", severity = "warning")
  out <- herald:::.spec_findings_rows(f)
  expect_true(grepl("sev-high", out))
})

test_that(".spec_findings_rows assigns sev-medium class to Medium severity", {
  f <- .make_spec_findings(status = "fired", severity = "medium")
  out <- herald:::.spec_findings_rows(f)
  expect_true(grepl("sev-medium", out))
})

test_that(".spec_findings_rows assigns sev-low for unknown severity", {
  f <- .make_spec_findings(status = "fired", severity = "informational")
  out <- herald:::.spec_findings_rows(f)
  expect_true(grepl("sev-low", out))
})

test_that(".spec_findings_rows includes variable in location when present", {
  f <- .make_spec_findings(
    status = "fired",
    severity = "High",
    dataset = "AE",
    variable = "AETERM",
    row = 5L
  )
  out <- herald:::.spec_findings_rows(f)
  expect_true(grepl("AE", out))
  expect_true(grepl("AETERM", out))
  expect_true(grepl("row 5", out))
})

test_that(".spec_findings_rows handles missing dataset gracefully", {
  f <- .make_spec_findings(
    status = "fired",
    severity = "High",
    dataset = "",
    variable = "",
    row = NA_integer_
  )
  out <- herald:::.spec_findings_rows(f)
  # Should not error and should produce a row
  expect_true(grepl("<tr>", out))
})

test_that(".spec_findings_rows HTML-escapes special characters", {
  f <- .make_spec_findings(
    status = "fired",
    severity = "High",
    message = "<script>alert('xss')</script>"
  )
  out <- herald:::.spec_findings_rows(f)
  expect_false(grepl("<script>", out))
  expect_true(grepl("&lt;script&gt;", out))
})

# -- write_spec_report_html: fired and advisory counts in output ---------------

test_that("write_spec_report_html reflects fired/advisory counts in output", {
  path <- withr::local_tempfile(fileext = ".html")
  findings <- .make_spec_findings(
    status = c("fired", "fired", "advisory"),
    severity = c("Reject", "High", "Medium"),
    rule_id = c("SPEC-001", "SPEC-002", "SPEC-003"),
    dataset = c("DM", "AE", "LB"),
    variable = c("USUBJID", "AETERM", "LBTEST"),
    row = c(1L, 2L, 3L),
    value = c("bad", "", ""),
    message = c("msg1", "msg2", "msg3")
  )
  herald:::write_spec_report_html(findings, path)
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  # Both fired IDs should appear
  expect_true(grepl("SPEC-001", content))
  expect_true(grepl("SPEC-002", content))
  # Advisory is not in fired rows
  expect_false(grepl("SPEC-003", content))
})

test_that("write_spec_report_html renders dataset-only location (no variable)", {
  path <- withr::local_tempfile(fileext = ".html")
  findings <- .make_spec_findings(
    status = "fired",
    severity = "High",
    dataset = "DM",
    variable = "",
    row = NA_integer_
  )
  herald:::write_spec_report_html(findings, path)
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_true(grepl("DM", content))
})

test_that("write_spec_report_html counts N_FIRED and N_ADVISORY placeholders", {
  path <- withr::local_tempfile(fileext = ".html")
  findings <- .make_spec_findings(
    status = c("fired", "advisory"),
    severity = c("Reject", "Medium"),
    rule_id = c("SPEC-001", "SPEC-002"),
    dataset = c("DM", "AE"),
    variable = c("USUBJID", "AETERM"),
    row = c(1L, NA_integer_),
    value = c("bad", ""),
    message = c("fired msg", "advisory msg")
  )
  herald:::write_spec_report_html(findings, path)
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  # No unresolved placeholders remain
  expect_false(grepl("[{][{][A-Z_]+[}][}]", content))
})
