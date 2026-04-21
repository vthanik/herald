# Tests for R/rules-findings.R

.rule <- function(...) {
  list(
    id         = "TEST0001",
    authority  = "CDISC",
    standard   = "SDTM-IG",
    severity   = "High",
    message    = "Sample message",
    source_url = "https://example.org/rule",
    ...
  )
}

test_that("emit_submission_finding() returns one row with <submission> dataset", {
  f <- emit_submission_finding(.rule())
  expect_equal(nrow(f), 1L)
  expect_equal(f$dataset, "<submission>")
  expect_true(is.na(f$row))
  expect_equal(f$status, "fired")
  expect_equal(f$rule_id, "TEST0001")
  expect_equal(f$severity, "High")
  expect_equal(f$message, "Sample message")
})

test_that("emit_submission_finding() matches empty_findings() schema", {
  expect_named(emit_submission_finding(.rule()), names(empty_findings()))
  f <- emit_submission_finding(.rule())
  for (col in names(empty_findings())) {
    expect_type(f[[col]], typeof(empty_findings()[[col]]))
  }
})

test_that("emit_submission_finding() honours overrides", {
  f <- emit_submission_finding(
    .rule(),
    status   = "advisory",
    message  = "ADSL dataset not found",
    severity = "Reject",
    variable = "ADSL",
    value    = NA_character_
  )
  expect_equal(f$status, "advisory")
  expect_equal(f$message, "ADSL dataset not found")
  expect_equal(f$severity, "Reject")
  expect_equal(f$variable, "ADSL")
})

test_that("emit_submission_finding() rejects unknown status", {
  expect_error(emit_submission_finding(.rule(), status = "error"))
})

test_that("emit_submission_finding() falls back on missing rule fields", {
  f <- emit_submission_finding(list(id = "X"))
  expect_equal(f$rule_id, "X")
  expect_true(is.na(f$authority))
  expect_equal(f$severity, "Medium")  # default when rule lacks severity
  expect_true(is.na(f$message))
})
