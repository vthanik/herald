# -----------------------------------------------------------------------------
# test-val-result.R -- herald_result S3 + print/summary/readiness
# -----------------------------------------------------------------------------

# -- helpers ------------------------------------------------------------------

.make_findings <- function(
  status = character(),
  severity = character()
) {
  tibble::tibble(
    rule_id = character(length(status)),
    authority = character(length(status)),
    standard = character(length(status)),
    severity = severity,
    severity_override = character(length(status)),
    status = status,
    dataset = character(length(status)),
    variable = character(length(status)),
    row = integer(length(status)),
    value = character(length(status)),
    expected = character(length(status)),
    message = character(length(status)),
    source_url = character(length(status)),
    p21_id_equivalent = character(length(status)),
    license = character(length(status))
  )
}

.make_result <- function(
  findings = herald:::empty_findings(),
  rules_applied = 10L,
  rules_total = 10L,
  datasets_checked = c("DM"),
  op_errors = list(),
  profile = NA_character_
) {
  herald:::new_herald_result(
    findings = findings,
    rules_applied = rules_applied,
    rules_total = rules_total,
    datasets_checked = datasets_checked,
    duration = as.difftime(1.2, units = "secs"),
    profile = profile,
    op_errors = op_errors
  )
}

# -- new_herald_result --------------------------------------------------------

test_that("new_herald_result creates correct structure", {
  r <- herald:::new_herald_result()
  expect_s3_class(r, "herald_result")
  expect_true(is.list(r))
  expect_type(r$rules_applied, "integer")
  expect_type(r$rules_total, "integer")
  expect_type(r$datasets_checked, "character")
  expect_s3_class(r$findings, "data.frame")
  expect_type(r$op_errors, "list")
})

# -- readiness_state ----------------------------------------------------------

test_that("readiness_state is 'Spec Checks Only' when rules_total == 0", {
  r <- .make_result(rules_applied = 0L, rules_total = 0L)
  expect_equal(herald:::readiness_state(r), "Spec Checks Only")
})

test_that("readiness_state is 'Incomplete' when < 90% rules applied", {
  r <- .make_result(rules_applied = 5L, rules_total = 10L)
  expect_equal(herald:::readiness_state(r), "Incomplete")
})

test_that("readiness_state is 'Issues Found' when Reject findings fired", {
  f <- .make_findings(status = c("fired", "fired"), severity = c("Reject", "High"))
  r <- .make_result(findings = f, rules_applied = 10L, rules_total = 10L)
  expect_equal(herald:::readiness_state(r), "Issues Found")
})

test_that("readiness_state is 'Issues Found' when only High findings fired", {
  f <- .make_findings(status = "fired", severity = "High")
  r <- .make_result(findings = f, rules_applied = 10L, rules_total = 10L)
  expect_equal(herald:::readiness_state(r), "Issues Found")
})

test_that("readiness_state is 'Submission Ready' with no reject/high fired", {
  f <- .make_findings(status = "advisory", severity = "Medium")
  r <- .make_result(findings = f, rules_applied = 10L, rules_total = 10L)
  expect_equal(herald:::readiness_state(r), "Submission Ready")
})

test_that("readiness_state is 'Submission Ready' with zero findings", {
  r <- .make_result(findings = herald:::empty_findings())
  expect_equal(herald:::readiness_state(r), "Submission Ready")
})

# -- print.herald_result ------------------------------------------------------

test_that("print.herald_result snapshot with 0 findings", {
  r <- .make_result(findings = herald:::empty_findings())
  expect_snapshot(print(r))
})

test_that("print.herald_result snapshot with fired findings and severity counts", {
  f <- .make_findings(
    status = c("fired", "fired", "advisory"),
    severity = c("Reject", "High", "Medium")
  )
  r <- .make_result(findings = f, rules_applied = 10L, rules_total = 10L)
  expect_snapshot(print(r))
})

test_that("print.herald_result snapshot for Incomplete state", {
  r <- .make_result(rules_applied = 2L, rules_total = 10L)
  expect_snapshot(print(r))
})

test_that("print.herald_result shows profile when set", {
  r <- .make_result(profile = "sdtm-2.0")
  expect_snapshot(print(r))
})

test_that("print.herald_result shows op_errors warning", {
  r <- .make_result(op_errors = list(list(kind = "unresolved_crossref")))
  expect_snapshot(print(r))
})

test_that("print.herald_result returns x invisibly", {
  r <- .make_result()
  out <- withVisible(print(r))
  expect_false(out$visible)
  expect_identical(out$value, r)
})

# -- summary.herald_result ----------------------------------------------------

test_that("summary.herald_result snapshot with severity breakdown", {
  f <- .make_findings(
    status = c("fired", "fired", "fired", "advisory"),
    severity = c("Reject", "Reject", "High", "Medium")
  )
  r <- .make_result(findings = f)
  s <- summary(r)
  # Inspect stable fields only -- timestamp varies per run
  stable <- s[setdiff(names(s), "timestamp")]
  expect_snapshot(str(stable))
})

test_that("summary.herald_result returns named list with expected keys", {
  r <- .make_result()
  s <- summary(r)
  expect_type(s, "list")
  expected_names <- c(
    "state", "rules_applied", "rules_total", "datasets_checked",
    "n_findings_fired", "n_findings_advisory", "severity_counts",
    "duration", "timestamp"
  )
  expect_true(all(expected_names %in% names(s)))
})

test_that("summary counts fired and advisory correctly", {
  f <- .make_findings(
    status = c("fired", "advisory", "fired"),
    severity = c("Reject", "Medium", "High")
  )
  r <- .make_result(findings = f)
  s <- summary(r)
  expect_equal(s$n_findings_fired, 2L)
  expect_equal(s$n_findings_advisory, 1L)
})
