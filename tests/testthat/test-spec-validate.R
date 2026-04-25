# --------------------------------------------------------------------------
# test-spec-validate.R -- validate_spec() + write_spec_report_html()
# --------------------------------------------------------------------------

mk_clean_spec <- function() {
  as_herald_spec(
    ds_spec = data.frame(
      dataset = "DM",
      label = "Demographics",
      stringsAsFactors = FALSE
    ),
    var_spec = data.frame(
      dataset = "DM",
      variable = "USUBJID",
      stringsAsFactors = FALSE
    )
  )
}

# ---- validate_spec() input guard ------------------------------------------

test_that("validate_spec() rejects non-herald_spec inputs", {
  expect_error(
    validate_spec(list()),
    class = "herald_error_input"
  )
})

# ---- clean spec passes silently -------------------------------------------

test_that("validate_spec() returns invisibly when spec is clean", {
  spec <- mk_clean_spec()
  out <- validate_spec(spec, view = FALSE)
  expect_null(out)
})

# ---- spec report writer ---------------------------------------------------

mk_spec_findings <- function() {
  tibble::tibble(
    rule_id = c(
      "define_dataset_label_required",
      "define_variable_origin_required"
    ),
    authority = rep("herald", 2L),
    standard = rep("herald-spec", 2L),
    severity = c("Error", "Error"),
    severity_override = rep(NA_character_, 2L),
    status = rep("fired", 2L),
    dataset = c("Define_Dataset_Metadata", "Define_Variable_Metadata"),
    variable = c("label", "origin"),
    row = c(1L, 1L),
    value = c(NA_character_, NA_character_),
    expected = rep(NA_character_, 2L),
    message = c(
      "Dataset label (Description) is required for regulatory submissions.",
      "Origin is required for all variables."
    ),
    source_url = rep("herald-own", 2L),
    p21_id_equivalent = rep(NA_character_, 2L),
    license = rep("MIT", 2L)
  )
}

test_that("write_spec_report_html produces a valid self-contained document", {
  p <- withr::local_tempfile(fileext = ".html")
  f <- mk_spec_findings()
  write_spec_report_html(f, p)

  expect_true(file.exists(p))
  html <- paste(readLines(p, warn = FALSE), collapse = "\n")

  # No remote assets
  expect_false(grepl("<script[^>]*\\ssrc=", html))
  expect_false(grepl("<link[^>]*\\shref=\"https?://", html))

  # Rule id appears
  expect_true(grepl("define_dataset_label_required", html, fixed = TRUE))

  # Human message appears (not just a short code)
  expect_true(grepl("required for regulatory submissions", html, fixed = TRUE))

  # Severity badge present
  expect_true(
    grepl("sev-reject\\|sev-high\\|sev-badge", html) ||
      grepl("sev-badge", html, fixed = TRUE)
  )
})

test_that("write_spec_report_html escapes XSS-unsafe strings", {
  f <- mk_spec_findings()
  f$message[1] <- "<script>alert(1)</script>"
  p <- withr::local_tempfile(fileext = ".html")
  write_spec_report_html(f, p)
  html <- paste(readLines(p, warn = FALSE), collapse = "\n")
  expect_false(grepl("<script>alert", html, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;alert", html, fixed = TRUE))
})

test_that("write_spec_report_html handles empty findings", {
  p <- withr::local_tempfile(fileext = ".html")
  write_spec_report_html(empty_findings(), p)
  html <- paste(readLines(p, warn = FALSE), collapse = "\n")
  expect_true(file.exists(p))
  expect_true(grepl("No", html))
})
